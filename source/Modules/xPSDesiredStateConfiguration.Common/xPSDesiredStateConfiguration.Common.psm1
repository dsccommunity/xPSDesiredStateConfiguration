<#
    .SYNOPSIS
        Tests if the current machine is a Nano server.
#>
function Test-IsNanoServer
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param ()

    $isNanoServer = $false

    if (Test-CommandExists -Name 'Get-ComputerInfo')
    {
        $computerInfo = Get-ComputerInfo

        $computerIsServer = 'Server' -ieq $computerInfo.OsProductType

        if ($computerIsServer)
        {
            $isNanoServer = 'NanoServer' -ieq $computerInfo.OsServerLevel
        }
    }

    return $isNanoServer
}

<#
    .SYNOPSIS
        Tests whether or not the command with the specified name exists.
    .PARAMETER Name
        The name of the command to test for.
#>
function Test-CommandExists
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    $command = Get-Command -Name $Name -ErrorAction 'SilentlyContinue'
    return ($null -ne $command)
}

<#
    .SYNOPSIS
        This method is used to compare current and desired values for any DSC resource.

    .PARAMETER CurrentValues
        This is hash table of the current values that are applied to the resource.

    .PARAMETER DesiredValues
        This is a PSBoundParametersDictionary of the desired values for the resource.

    .PARAMETER ValuesToCheck
        This is a list of which properties in the desired values list should be checked.
        If this is empty then all values in DesiredValues are checked.
#>
function Test-DscParameterState
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $CurrentValues,

        [Parameter(Mandatory = $true)]
        [System.Object]
        $DesiredValues,

        [Parameter()]
        [System.Array]
        $ValuesToCheck
    )

    $returnValue = $true

    if (($DesiredValues.GetType().Name -ne 'HashTable') `
        -and ($DesiredValues.GetType().Name -ne 'CimInstance') `
        -and ($DesiredValues.GetType().Name -ne 'PSBoundParametersDictionary'))
    {
        $errorMessage = $script:localizedData.PropertyTypeInvalidForDesiredValues -f $($DesiredValues.GetType().Name)
        New-InvalidArgumentException -ArgumentName 'DesiredValues' -Message $errorMessage
    }

    if (($DesiredValues.GetType().Name -eq 'CimInstance') -and ($null -eq $ValuesToCheck))
    {
        $errorMessage = $script:localizedData.PropertyTypeInvalidForValuesToCheck
        New-InvalidArgumentException -ArgumentName 'ValuesToCheck' -Message $errorMessage
    }

    if (($null -eq $ValuesToCheck) -or ($ValuesToCheck.Count -lt 1))
    {
        $keyList = $DesiredValues.Keys
    }
    else
    {
        $keyList = $ValuesToCheck
    }

    $keyList | ForEach-Object -Process {
        if (($_ -ne 'Verbose'))
        {
            if (($CurrentValues.ContainsKey($_) -eq $false) `
            -or ($CurrentValues.$_ -ne $DesiredValues.$_) `
            -or (($DesiredValues.GetType().Name -ne 'CimInstance' -and $DesiredValues.ContainsKey($_) -eq $true) -and ($null -ne $DesiredValues.$_ -and $DesiredValues.$_.GetType().IsArray)))
            {
                if ($DesiredValues.GetType().Name -eq 'HashTable' -or `
                    $DesiredValues.GetType().Name -eq 'PSBoundParametersDictionary')
                {
                    $checkDesiredValue = $DesiredValues.ContainsKey($_)
                }
                else
                {
                    # If DesiredValue is a CimInstance.
                    $checkDesiredValue = $false
                    if (([System.Boolean]($DesiredValues.PSObject.Properties.Name -contains $_)) -eq $true)
                    {
                        if ($null -ne $DesiredValues.$_)
                        {
                            $checkDesiredValue = $true
                        }
                    }
                }

                if ($checkDesiredValue)
                {
                    $desiredType = $DesiredValues.$_.GetType()
                    $fieldName = $_
                    if ($desiredType.IsArray -eq $true)
                    {
                        if (($CurrentValues.ContainsKey($fieldName) -eq $false) `
                        -or ($null -eq $CurrentValues.$fieldName))
                        {
                            Write-Verbose -Message ($script:localizedData.PropertyValidationError -f $fieldName) -Verbose

                            $returnValue = $false
                        }
                        else
                        {
                            $arrayCompare = Compare-Object -ReferenceObject $CurrentValues.$fieldName `
                                                           -DifferenceObject $DesiredValues.$fieldName
                            if ($null -ne $arrayCompare)
                            {
                                Write-Verbose -Message ($script:localizedData.PropertiesDoesNotMatch -f $fieldName) -Verbose

                                $arrayCompare | ForEach-Object -Process {
                                    Write-Verbose -Message ($script:localizedData.PropertyThatDoesNotMatch -f $_.InputObject, $_.SideIndicator) -Verbose
                                }

                                $returnValue = $false
                            }
                        }
                    }
                    else
                    {
                        switch ($desiredType.Name)
                        {
                            'String'
                            {
                                if (-not [System.String]::IsNullOrEmpty($CurrentValues.$fieldName) -or `
                                    -not [System.String]::IsNullOrEmpty($DesiredValues.$fieldName))
                                {
                                    Write-Verbose -Message ($script:localizedData.ValueOfTypeDoesNotMatch `
                                        -f $desiredType.Name, $fieldName, $($CurrentValues.$fieldName), $($DesiredValues.$fieldName)) -Verbose

                                    $returnValue = $false
                                }
                            }

                            'Int32'
                            {
                                if (-not ($DesiredValues.$fieldName -eq 0) -or `
                                    -not ($null -eq $CurrentValues.$fieldName))
                                {
                                    Write-Verbose -Message ($script:localizedData.ValueOfTypeDoesNotMatch `
                                        -f $desiredType.Name, $fieldName, $($CurrentValues.$fieldName), $($DesiredValues.$fieldName)) -Verbose

                                    $returnValue = $false
                                }
                            }

                            { $_ -eq 'Int16' -or $_ -eq 'UInt16' -or $_ -eq 'Single' }
                            {
                                if (-not ($DesiredValues.$fieldName -eq 0) -or `
                                    -not ($null -eq $CurrentValues.$fieldName))
                                {
                                    Write-Verbose -Message ($script:localizedData.ValueOfTypeDoesNotMatch `
                                        -f $desiredType.Name, $fieldName, $($CurrentValues.$fieldName), $($DesiredValues.$fieldName)) -Verbose

                                    $returnValue = $false
                                }
                            }

                            'Boolean'
                            {
                                if ($CurrentValues.$fieldName -ne $DesiredValues.$fieldName)
                                {
                                    Write-Verbose -Message ($script:localizedData.ValueOfTypeDoesNotMatch `
                                        -f $desiredType.Name, $fieldName, $($CurrentValues.$fieldName), $($DesiredValues.$fieldName)) -Verbose

                                    $returnValue = $false
                                }
                            }

                            default
                            {
                                Write-Warning -Message ($script:localizedData.UnableToCompareProperty `
                                    -f $fieldName, $desiredType.Name)

                                $returnValue = $false
                            }
                        }
                    }
                }
            }
        }
    }

    return $returnValue
}

<#
    .SYNOPSIS
        Retrieves the localized string data based on the machine's culture.
        Falls back to en-US strings if the machine's culture is not supported.

    .PARAMETER ResourceName
        The name of the resource as it appears before '.strings.psd1' of the localized string file.
        For example:
            For WindowsOptionalFeature: MSFT_WindowsOptionalFeature
            For Service: MSFT_ServiceResource
            For Registry: MSFT_RegistryResource
            For Helper: SqlServerDscHelper

    .PARAMETER ScriptRoot
        Optional. The root path where to expect to find the culture folder. This is only needed
        for localization in helper modules. This should not normally be used for resources.

    .NOTES
        To be able to use localization in the helper function, this function must
        be first in the file, before Get-LocalizedData is used by itself to load
        localized data for this helper module (see directly after this function).
#>
function Get-LocalizedData
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ResourceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ScriptRoot
    )

    if (-not $ScriptRoot)
    {
        $dscResourcesFolder = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'DSCResources'
        $resourceDirectory = Join-Path -Path $dscResourcesFolder -ChildPath $ResourceName
    }
    else
    {
        $resourceDirectory = $ScriptRoot
    }

    $localizedStringFileLocation = Join-Path -Path $resourceDirectory -ChildPath $PSUICulture

    if (-not (Test-Path -Path $localizedStringFileLocation))
    {
        # Fallback to en-US
        $localizedStringFileLocation = Join-Path -Path $resourceDirectory -ChildPath 'en-US'
    }

    Import-LocalizedData `
        -BindingVariable 'localizedData' `
        -FileName "$ResourceName.strings.psd1" `
        -BaseDirectory $localizedStringFileLocation

    return $localizedData
}

<#
    .SYNOPSIS
        Creates and throws an invalid argument exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ArgumentName
        The name of the invalid argument that is causing this error to be thrown.
#>
function New-InvalidArgumentException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ArgumentName
    )

    $argumentException = New-Object -TypeName 'ArgumentException' `
        -ArgumentList @($Message, $ArgumentName)

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @($argumentException, $ArgumentName, 'InvalidArgument', $null)
    }

    $errorRecord = New-Object @newObjectParameters

    throw $errorRecord
}

<#
    .SYNOPSIS
        Creates and throws an invalid operation exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.
#>
function New-InvalidOperationException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException' `
            -ArgumentList @($Message)
    }
    else
    {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $invalidOperationException.ToString(),
            'MachineStateIncorrect',
            'InvalidOperation',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}

<#
    .SYNOPSIS
        Creates and throws an object not found exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.
#>
function New-ObjectNotFoundException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message)
    }
    else
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $exception.ToString(),
            'MachineStateIncorrect',
            'ObjectNotFound',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}

<#
    .SYNOPSIS
        Creates and throws an invalid result exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.
#>
function New-InvalidResultException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message)
    }
    else
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $exception.ToString(),
            'MachineStateIncorrect',
            'InvalidResult',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}

function New-NotImplementedException
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $invalidOperationException = New-Object -TypeName 'NotImplementedException' `
            -ArgumentList @($Message)
    }
    else
    {
        $invalidOperationException = New-Object -TypeName 'NotImplementedException' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $invalidOperationException.ToString(),
            'MachineStateIncorrect',
            'NotImplemented',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}

<#
    .SYNOPSIS
        Sets the Global DSCMachineStatus variable to a value of 1.
#>
function Set-DscMachineRebootRequired
{
    # Suppressing this rule because $global:DSCMachineStatus is used to trigger a reboot.
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    <#
        Suppressing this rule because $global:DSCMachineStatus is only set,
        never used (by design of Desired State Configuration).
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    [CmdletBinding()]
    param
    (
    )

    $global:DSCMachineStatus = 1
}

<#
    .SYNOPSIS
        Builds a string of the common parameters shared across all resources in a set.

    .PARAMETER KeyParameterName
        The name of the key parameter for the resource.

    .PARAMETER Parameters
        The hashtable of all parameters to the resource set (PSBoundParameters).

    .EXAMPLE
        $parameters = @{
            KeyParameter = @( 'MyKeyParameter1', 'MyKeyParameter2' )
            CommonParameter1 = 'CommonValue1'
            CommonParameter2 = 2
        }

        New-ResourceSetCommonParameterString -KeyParameterName 'KeyParameter' -Parameters $parameters

        OUTPUT (as string):
        CommonParameter1 = "CommonValue1"`r`nCommonParameter2 = $CommonParameter2
#>
function New-ResourceSetCommonParameterString
{
    [OutputType([System.String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $KeyParameterName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $Parameters
    )

    $stringBuilder = New-Object -TypeName 'System.Text.StringBuilder'

    foreach ($parameterName in $Parameters.Keys)
    {
        # All composite resources have an extra parameter 'InstanceName'
        if ($parameterName -ine $KeyParameterName -and $parameterName -ine 'InstanceName')
        {
            $parameterValue = $Parameters[$parameterName]

            if ($null -ne $parameterValue)
            {
                if ($parameterValue -is [System.String])
                {
                    $null = $stringBuilder.AppendFormat('{0} = "{1}"', $parameterName, $parameterValue)
                }
                else
                {
                    $null = $stringBuilder.Append($parameterName + ' = $' + $parameterName)
                }

                $null = $stringBuilder.AppendLine()
            }
        }
    }

    return $stringBuilder.ToString()
}

<#
    .SYNOPSIS
        Creates a string representing a configuration script for a set of resources.

    .PARAMETER ResourceName
        The name of the resource to create a set of.

    .PARAMETER ModuleName
        The name of the module to import the resource from.

    .PARAMETER KeyParameterName
        The name of the key parameter that will differentiate each resource.

    .PARAMETER KeyParameterValues
        An array of the values of the key parameter that will differentiate each resource.

    .PARAMETER CommonParameterString
        A string representing the common parameters for each resource.
        Can be retrieved from New-ResourceSetCommonParameterString.

    .EXAMPLE
        New-ResourceSetConfigurationString `
            -ResourceName 'xWindowsFeature' `
            -ModuleName 'xPSDesiredStateConfiguration' `
            -KeyParameterName 'Name' `
            -KeyParameterValues @( 'Telnet-Client', 'Web-Server' ) `
            -CommonParameterString 'Ensure = "Present"`r`nIncludeAllSubFeature = $true'

        OUTPUT (as a String):
            Import-Module -Name xWindowsFeature -ModuleName xPSDesiredStateConfiguration

            xWindowsFeature Resource0
            {
                Name = "Telnet-Client"
                Ensure = "Present"
                IncludeAllSubFeature = $true
            }

            xWindowsFeature Resource1
            {
                Name = "Web-Server"
                Ensure = "Present"
                IncludeAllSubFeature = $true
            }
#>
function New-ResourceSetConfigurationString
{
    [OutputType([System.String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ResourceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $KeyParameterName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $KeyParameterValues,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CommonParameterString
    )

    $stringBuilder = New-Object -TypeName 'System.Text.StringBuilder'

    $null = $stringBuilder.AppendFormat('Import-DscResource -Name {0} -ModuleName {1}', $ResourceName, $ModuleName)
    $null = $stringBuilder.AppendLine()

    $resourceCount = 0
    foreach ($keyParameterValue in $KeyParameterValues)
    {
        $null = $stringBuilder.AppendFormat('{0} Resource{1}', $ResourceName, $resourceCount)
        $null = $stringBuilder.AppendLine()
        $null = $stringBuilder.AppendLine('{')
        $null = $stringBuilder.AppendFormat($KeyParameterName + ' = "{0}"', $keyParameterValue)
        $null = $stringBuilder.AppendLine()
        $null = $stringBuilder.Append($CommonParameterString)
        $null = $stringBuilder.AppendLine('}')

        $resourceCount++
    }

    return $stringBuilder.ToString()
}

<#
    .SYNOPSIS
        Creates a configuration script block for a set of resources.

    .PARAMETER ResourceName
        The name of the resource to create a set of.

    .PARAMETER ModuleName
        The name of the module to import the resource from.

    .PARAMETER KeyParameterName
        The name of the key parameter that will differentiate each resource.

    .PARAMETER Parameters
        The hashtable of all parameters to the resource set (PSBoundParameters).

    .EXAMPLE
        # From the xGroupSet composite resource

        $newResourceSetConfigurationParams = @{
            ResourceName = 'xGroup'
            ModuleName = 'xPSDesiredStateConfiguration'
            KeyParameterName = 'GroupName'
            CommonParameterNames = @( 'Ensure', 'MembersToInclude', 'MembersToExclude', 'Credential' )
            Parameters = $PSBoundParameters
        }

        $configurationScriptBlock = New-ResourceSetConfigurationScriptBlock @newResourceSetConfigurationParams

    .NOTES
        Only allows one key parameter to be defined for each node.
        For resources with multiple key parameters, only one key can be different for each resource.
        See xProcessSet for an example of a resource set with two key parameters.
#>
function New-ResourceSetConfigurationScriptBlock
{
    [OutputType([System.Management.Automation.ScriptBlock])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ResourceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $KeyParameterName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $Parameters
    )

    $commonParameterString = New-ResourceSetCommonParameterString -KeyParameterName $KeyParameterName -Parameters $Parameters

    $newResourceSetConfigurationStringParams = @{
        ResourceName = $ResourceName
        ModuleName = $ModuleName
        KeyParameterName = $KeyParameterName
        KeyParameterValues = $Parameters[$KeyParameterName]
        CommonParameterString = $commonParameterString
    }

    $resourceString = New-ResourceSetConfigurationString @newResourceSetConfigurationStringParams

    return [System.Management.Automation.ScriptBlock]::Create($resourceString)
}

New-Variable -Name DscWebServiceDefaultAppPoolName  -Value 'PSWS' -Option ReadOnly -Force -Scope Script

<#
    .SYNOPSIS
        Validate supplied configuration to setup the PSWS Endpoint Function
        checks for the existence of PSWS Schema files, IIS config Also validate
        presence of IIS on the target machine
#>
function Initialize-Endpoint
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $appPool,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $site,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $cfgfile,

        [Parameter()]
        [System.Int32]
        $port,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $app,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $applicationPoolIdentityType,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $svc,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $mof,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $dispatch,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $asax,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentBinaries,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $language,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentMUIFiles,

        [Parameter()]
        [System.String[]]
        $psFiles,

        [Parameter()]
        [System.Boolean]
        $removeSiteFiles = $false,

        [Parameter()]
        [System.String]
        $certificateThumbPrint,

        [Parameter()]
        [System.Boolean]
        $enable32BitAppOnWin64
    )

    if ($certificateThumbPrint -ne 'AllowUnencryptedTraffic')
    {
        Write-Verbose -Message 'Verify that the certificate with the provided thumbprint exists in CERT:\LocalMachine\MY\'

        $certificate = Get-ChildItem -Path CERT:\LocalMachine\MY\ | Where-Object -FilterScript {
            $_.Thumbprint -eq $certificateThumbPrint
        }

        if (!$Certificate)
        {
             throw "ERROR: Certificate with thumbprint $certificateThumbPrint does not exist in CERT:\LocalMachine\MY\"
        }
    }

    Test-IISInstall

    # First remove the site so that the binding count on the application pool is reduced
    Update-Site -siteName $site -siteAction Remove

    Remove-AppPool -appPool $appPool

    # Check for existing binding, there should be no binding with the same port
    $allWebBindingsOnPort = Get-WebBinding | Where-Object -FilterScript {
        $_.BindingInformation -eq "*:$($port):"
    }

    if ($allWebBindingsOnPort.Count -gt 0)
    {
        throw "ERROR: Port $port is already used, please review existing sites and change the port to be used."
    }

    if ($removeSiteFiles)
    {
        if (Test-Path -Path $path)
        {
            Remove-Item -Path $path -Recurse -Force
        }
    }

    Copy-PSWSConfigurationToIISEndpointFolder -path $path `
        -cfgfile $cfgfile `
        -svc $svc `
        -mof $mof `
        -dispatch $dispatch `
        -asax $asax `
        -dependentBinaries $dependentBinaries `
        -language $language `
        -dependentMUIFiles $dependentMUIFiles `
        -psFiles $psFiles

    New-IISWebSite -site $site `
        -path $path `
        -port $port `
        -app $app `
        -apppool $appPool `
        -applicationPoolIdentityType $applicationPoolIdentityType `
        -certificateThumbPrint $certificateThumbPrint `
        -enable32BitAppOnWin64 $enable32BitAppOnWin64
}

<#
    .SYNOPSIS
        Validate if IIS and all required dependencies are installed on the
        target machine
#>
function Test-IISInstall
{
    [CmdletBinding()]
    param ()

    Write-Verbose -Message 'Checking IIS requirements'
    $iisVersion = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\InetStp -ErrorAction silentlycontinue).MajorVersion

    if ($iisVersion -lt 7)
    {
        throw "ERROR: IIS Version detected is $iisVersion , must be running higher than 7.0"
    }

    $wsRegKey = (Get-ItemProperty hklm:\SYSTEM\CurrentControlSet\Services\W3SVC -ErrorAction silentlycontinue).ImagePath
    if ($null -eq $wsRegKey)
    {
        throw 'ERROR: Cannot retrive W3SVC key. IIS Web Services may not be installed'
    }

    if ((Get-Service w3svc).Status -ne 'running')
    {
        throw 'ERROR: service W3SVC is not running'
    }
}

<#
    .SYNOPSIS
        Verify if a given IIS Site exists
#>
function Test-ForIISSite
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [System.String]
        $siteName
    )

    if (Get-Website -Name $siteName)
    {
        return $true
    }

    return $false
}

<#
    .SYNOPSIS
        Perform an action (such as stop, start, delete) for a given IIS Site
#>
function Update-Site
{
    param
    (
        [Parameter(ParameterSetName = 'SiteName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $siteName,

        [Parameter(ParameterSetName = 'Site', Mandatory = $true, Position = 0)]
        [System.Object]
        $site,

        [Parameter(ParameterSetName = 'SiteName', Mandatory = $true, Position = 1)]
        [Parameter(ParameterSetName = 'Site', Mandatory = $true, Position = 1)]
        [System.String]
        [ValidateSet('Start', 'Stop', 'Remove')]
        $siteAction
    )

    if ('SiteName' -eq  $PSCmdlet.ParameterSetName)
    {
        $site = Get-Website -Name $siteName
    }

    if ($site)
    {
        switch ($siteAction)
        {
            'Start'
            {
                Write-Verbose -Message "Starting IIS Website [$($site.name)]"
                Start-Website -Name $site.name
            }

            'Stop'
            {
                if ('Started' -eq $site.state)
                {
                    Write-Verbose -Message "Stopping WebSite $($site.name)"
                    $website = Stop-Website -Name $site.name -Passthru

                    if ('Started' -eq $website.state)
                    {
                        throw "Unable to stop WebSite $($site.name)"
                    }

                    <#
                      There may be running requests, wait a little
                      I had an issue where the files were still in use
                      when I tried to delete them
                    #>
                    Write-Verbose -Message 'Waiting for IIS to stop website'
                    Start-Sleep -Milliseconds 1000
                }
                else
                {
                    Write-Verbose -Message "IIS Website [$($site.name)] already stopped"
                }
            }

            'Remove'
            {
                Update-Site -site $site -siteAction Stop
                Write-Verbose -Message "Removing IIS Website [$($site.name)]"
                Remove-Website -Name $site.name
            }
        }
    }
    else
    {
        Write-Verbose -Message "IIS Website [$siteName] not found"
    }
}

<#
    .SYNOPSIS
        Returns the list of bound sites and applications for a given IIS Application pool

    .PARAMETER appPool
        The application pool name
#>
function Get-AppPoolBinding
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AppPool
    )

    if (Test-Path -Path "IIS:\AppPools\$AppPool")
    {
        $sites = Get-WebConfigurationProperty `
            -Filter "/system.applicationHost/sites/site/application[@applicationPool=`'$AppPool`'and @path='/']/parent::*" `
            -PSPath 'machine/webroot/apphost' `
            -Name name
        $apps = Get-WebConfigurationProperty `
            -Filter "/system.applicationHost/sites/site/application[@applicationPool=`'$AppPool`'and @path!='/']" `
            -PSPath 'machine/webroot/apphost' `
            -Name path
        $sites, $apps | ForEach-Object {
            $_.Value
        }
    }
}

<#
    .SYNOPSIS
        Delete the given IIS Application Pool. This is required to cleanup any
        existing conflicting apppools before setting up the endpoint.
#>
function Remove-AppPool
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AppPool
    )

    if ($DscWebServiceDefaultAppPoolName -eq $AppPool)
    {
        # Without this tests we may get a breaking error here, despite SilentlyContinue
        if (Test-Path -Path "IIS:\AppPools\$AppPool")
        {
            $bindingCount = (Get-AppPoolBinding -AppPool $AppPool | Measure-Object).Count

            if (0 -ge $bindingCount)
            {
                Remove-WebAppPool -Name $AppPool -ErrorAction SilentlyContinue
            }
            else
            {
                Write-Verbose -Message "Application pool [$AppPool] can't be deleted because it's still bound to a site or application"
            }
        }
    }
    else
    {
        Write-Verbose -Message "ApplicationPool can't be deleted because the name is different from built-in name [$DscWebServiceDefaultAppPoolName]."
    }
}

<#
    .SYNOPSIS
        Generate an IIS Site Id while setting up the endpoint. The Site Id will
        be the max available in IIS config + 1.
#>
function New-SiteID
{
    [CmdletBinding()]
    param ()

    return ((Get-Website | Foreach-Object -Process { $_.Id } | Measure-Object -Maximum).Maximum + 1)
}

<#
    .SYNOPSIS
        Copies the supplied PSWS config files to the IIS endpoint in inetpub
#>
function Copy-PSWSConfigurationToIISEndpointFolder
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String]
        $path,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $cfgfile,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $svc,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $mof,

        [Parameter()]
        [System.String]
        $dispatch,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $asax,

        [Parameter()]
        [System.String[]]
        $dependentBinaries,

        [Parameter()]
        [System.String]
        $language,

        [Parameter()]
        [System.String[]]
        $dependentMUIFiles,

        [Parameter()]
        [System.String[]]
        $psFiles
    )

    if (!(Test-Path -Path $path))
    {
        $null = New-Item -ItemType container -Path $path
    }

    foreach ($dependentBinary in $dependentBinaries)
    {
        if (!(Test-Path -Path $dependentBinary))
        {
            throw "ERROR: $dependentBinary does not exist"
        }
    }

    Write-Verbose -Message 'Create the bin folder for deploying custom dependent binaries required by the endpoint'
    $binFolderPath = Join-Path -Path $path -ChildPath 'bin'
    $null = New-Item -Path $binFolderPath  -ItemType 'directory' -Force
    Copy-Item -Path $dependentBinaries -Destination $binFolderPath -Force

    foreach ($psFile in $psFiles)
    {
        if (!(Test-Path -Path $psFile))
        {
            throw "ERROR: $psFile does not exist"
        }

        Copy-Item -Path $psFile -Destination $path -Force
    }

    Copy-Item -Path $cfgfile (Join-Path -Path $path -ChildPath 'web.config') -Force
    Copy-Item -Path $svc -Destination $path -Force
    Copy-Item -Path $mof -Destination $path -Force

    if ($dispatch)
    {
        Copy-Item -Path $dispatch -Destination $path -Force
    }

    if ($asax)
    {
        Copy-Item -Path $asax -Destination $path -Force
    }
}

<#
    .SYNOPSIS
        Setup IIS Apppool, Site and Application
#>
function New-IISWebSite
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $site,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $port,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $app,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $appPool,

        [Parameter()]
        [System.String]
        $applicationPoolIdentityType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $certificateThumbPrint,

        [Parameter()]
        [System.Boolean]
        $enable32BitAppOnWin64
    )

    $siteID = New-SiteID

    if (Test-Path IIS:\AppPools\$appPool)
    {
        Write-Verbose -Message "Application Pool [$appPool] already exists"
    }
    else
    {
        Write-Verbose -Message "Adding App Pool [$appPool]"
        $null = New-WebAppPool -Name $appPool

        Write-Verbose -Message 'Set App Pool Properties'
        $appPoolIdentity = 4

        if ($applicationPoolIdentityType)
        {
            # LocalSystem = 0, LocalService = 1, NetworkService = 2, SpecificUser = 3, ApplicationPoolIdentity = 4
            switch ($applicationPoolIdentityType)
            {
                'LocalSystem'
                {
                    $appPoolIdentity = 0
                }

                'LocalService'
                {
                    $appPoolIdentity = 1
                }

                'NetworkService'
                {
                    $appPoolIdentity = 2
                }

                'ApplicationPoolIdentity'
                {
                    $appPoolIdentity = 4
                }

                default {
                    throw "Invalid value [$applicationPoolIdentityType] for parameter -applicationPoolIdentityType"
                }
            }
        }

        $appPoolItem = Get-Item -Path IIS:\AppPools\$appPool
        $appPoolItem.managedRuntimeVersion = 'v4.0'
        $appPoolItem.enable32BitAppOnWin64 = $enable32BitAppOnWin64
        $appPoolItem.processModel.identityType = $appPoolIdentity
        $appPoolItem | Set-Item

    }

    Write-Verbose -Message 'Add and Set Site Properties'

    if ($certificateThumbPrint -eq 'AllowUnencryptedTraffic')
    {
        $null = New-WebSite -Name $site -Id $siteID -Port $port -IPAddress "*" -PhysicalPath $path -ApplicationPool $appPool
    }
    else
    {
        $null = New-WebSite -Name $site -Id $siteID -Port $port -IPAddress "*" -PhysicalPath $path -ApplicationPool $appPool -Ssl

        # Remove existing binding for $port
        Remove-Item IIS:\SSLBindings\0.0.0.0!$port -ErrorAction Ignore

        # Create a new binding using the supplied certificate
        $null = Get-Item CERT:\LocalMachine\MY\$certificateThumbPrint | New-Item IIS:\SSLBindings\0.0.0.0!$port
    }

    Update-Site -siteName $site -siteAction Start
}

<#
    .SYNOPSIS
        Enable & Clear PSWS Operational/Analytic/Debug ETW Channels.
#>
function Enable-PSWSETW
{
    # Disable Analytic Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Analytic /e:false /q

    # Disable Debug Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Debug /e:false /q

    # Clear Operational Log
    $null = & $script:wevtutil cl Microsoft-Windows-ManagementOdataService/Operational

    # Enable/Clear Analytic Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Analytic /e:true /q

    # Enable/Clear Debug Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Debug /e:true /q
}

<#
    .SYNOPSIS
        Create PowerShell WebServices IIS Endpoint

    .DESCRIPTION
        Creates a PSWS IIS Endpoint by consuming PSWS Schema and related
        dependent files

    .EXAMPLE
        New PSWS Endpoint [@ http://Server:39689/PSWS_Win32Process] by
        consuming PSWS Schema Files and any dependent scripts/binaries:

        New-PSWSEndpoint
            -site Win32Process
            -path $env:SystemDrive\inetpub\PSWS_Win32Process
            -cfgfile Win32Process.config
            -port 39689
            -app Win32Process
            -svc PSWS.svc
            -mof Win32Process.mof
            -dispatch Win32Process.xml
            -dependentBinaries ConfigureProcess.ps1, Rbac.dll
            -psFiles Win32Process.psm1
#>
function New-PSWSEndpoint
{
    [CmdletBinding()]
    param
    (
        # Unique Name of the IIS Site
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $site = 'PSWS',

        # Physical path for the IIS Endpoint on the machine (under inetpub)
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path = "$env:SystemDrive\inetpub\PSWS",

        # Web.config file
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $cfgfile = 'web.config',

        # Port # for the IIS Endpoint
        [Parameter()]
        [System.Int32]
        $port = 8080,

        # IIS Application Name for the Site
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $app = 'PSWS',

        # IIS Application Name for the Site
        [Parameter()]
        [System.String]
        $appPool,

        # IIS App Pool Identity Type - must be one of LocalService, LocalSystem, NetworkService, ApplicationPoolIdentity
        [Parameter()]
        [ValidateSet('LocalService', 'LocalSystem', 'NetworkService', 'ApplicationPoolIdentity')]
        [System.String]
        $applicationPoolIdentityType,

        # WCF Service SVC file
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $svc = 'PSWS.svc',

        # PSWS Specific MOF Schema File
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $mof,

        # PSWS Specific Dispatch Mapping File [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $dispatch,

        # Global.asax file [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $asax,

        # Any dependent binaries that need to be deployed to the IIS endpoint, in the bin folder
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentBinaries,

         # MUI Language [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $language,

        # Any dependent binaries that need to be deployed to the IIS endpoint, in the bin\mui folder [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentMUIFiles,

        # Any dependent PowerShell Scipts/Modules that need to be deployed to the IIS endpoint application root
        [Parameter()]
        [System.String[]]
        $psFiles,

        # True to remove all files for the site at first, false otherwise
        [Parameter()]
        [System.Boolean]
        $removeSiteFiles = $false,

        # Enable and Clear PSWS ETW
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $EnablePSWSETW,

        # Thumbprint of the Certificate in CERT:\LocalMachine\MY\ for Pull Server
        [Parameter()]
        [System.String]
        $certificateThumbPrint = 'AllowUnencryptedTraffic',

        # When this property is set to true, Pull Server will run on a 32 bit process on a 64 bit machine
        [Parameter()]
        [System.Boolean]
        $Enable32BitAppOnWin64 = $false
    )

    if (-not $appPool)
    {
        $appPool = $DscWebServiceDefaultAppPoolName
    }

    $script:wevtutil = "$env:windir\system32\Wevtutil.exe"

    $svcName = Split-Path $svc -Leaf
    $protocol = 'https:'

    if ($certificateThumbPrint -eq 'AllowUnencryptedTraffic')
    {
        $protocol = 'http:'
    }

    # Get Machine Name
    $cimInstance = Get-CimInstance -ClassName Win32_ComputerSystem -Verbose:$false

    Write-Verbose -Message "Setting up endpoint at - $protocol//$($cimInstance.Name):$port/$svcName"
    Initialize-Endpoint `
        -appPool $appPool `
        -site $site `
        -path $path `
        -cfgfile $cfgfile `
        -port $port `
        -app $app `
        -applicationPoolIdentityType $applicationPoolIdentityType `
        -svc $svc `
        -mof $mof `
        -dispatch $dispatch `
        -asax $asax `
        -dependentBinaries $dependentBinaries `
        -language $language `
        -dependentMUIFiles $dependentMUIFiles `
        -psFiles $psFiles `
        -removeSiteFiles $removeSiteFiles `
        -certificateThumbPrint $certificateThumbPrint `
        -enable32BitAppOnWin64 $Enable32BitAppOnWin64

    if ($EnablePSWSETW)
    {
        Enable-PSWSETW
    }
}

<#
    .SYNOPSIS
        Removes a DSC WebServices IIS Endpoint

    .DESCRIPTION
        Removes a PSWS IIS Endpoint

    .EXAMPLE
        Remove the endpoint with the specified name:

        Remove-PSWSEndpoint -siteName PSDSCPullServer
#>
function Remove-PSWSEndpoint
{
    [CmdletBinding()]
    param
    (
        # Unique Name of the IIS Site
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $siteName
    )

    # Get the site to remove
    $site = Get-Website -Name $siteName

    if ($site)
    {
        # And the pool it is using
        $pool = $site.applicationPool
        # Get the path so we can delete the files
        $filePath = $site.PhysicalPath

        # Remove the actual site.
        Update-Site -site $site -siteAction Remove

        # Remove the files for the site
        if (Test-Path -Path $filePath)
        {
            Get-ChildItem -Path $filePath -Recurse | Remove-Item -Recurse -Force
            Remove-Item -Path $filePath -Force
        }

        Remove-AppPool -appPool $pool
    }
    else
    {
        Write-Verbose -Message "Website with name [$siteName] does not exist"
    }
}

<#
    .SYNOPSIS
        Set the option into the web.config for an endpoint

    .DESCRIPTION
        Set the options into the web.config for an endpoint allowing
        customization.
#>
function Set-AppSettingsInWebconfig
{
    [CmdletBinding()]
    param
    (
        # Physical path for the IIS Endpoint on the machine (possibly under inetpub)
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        # Key to add/update
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        # Value
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Value
    )

    $webconfig = Join-Path -Path $Path -ChildPath 'web.config'
    [System.Boolean] $Found = $false

    if (Test-Path -Path $webconfig)
    {
        $xml = [System.Xml.XmlDocument] (Get-Content -Path $webconfig)
        $root = $xml.get_DocumentElement()

        foreach ($item in $root.appSettings.add)
        {
            if ($item.key -eq $Key)
            {
                $item.value = $Value;
                $Found = $true;
            }
        }

        if (-not $Found)
        {
            $newElement = $xml.CreateElement('add')
            $nameAtt1 = $xml.CreateAttribute('key')
            $nameAtt1.psbase.value = $Key;
            $null = $newElement.SetAttributeNode($nameAtt1)

            $nameAtt2 = $xml.CreateAttribute('value')
            $nameAtt2.psbase.value = $Value;
            $null = $newElement.SetAttributeNode($nameAtt2)

            $null = $xml.configuration['appSettings'].AppendChild($newElement)
        }
    }

    $xml.Save($webconfig)
}

<#
    .SYNOPSIS
        Set the binding redirect setting in the web.config to redirect 10.0.0.0
        version of microsoft.isam.esent.interop to 6.3.0.0.

    .DESCRIPTION
        This function creates the following section in the web.config:
        <runtime>
          <assemblyBinding xmlns='urn:schemas-microsoft-com:asm.v1'>
            <dependentAssembly>
              <assemblyIdentity name='microsoft.isam.esent.interop' publicKeyToken='31bf3856ad364e35' />
            <bindingRedirect oldVersion='10.0.0.0' newVersion='6.3.0.0' />
           </dependentAssembly>
          </assemblyBinding>
        </runtime>
#>
function Set-BindingRedirectSettingInWebConfig
{
    [CmdletBinding()]
    param
    (
        # Physical path for the IIS Endpoint on the machine (possibly under inetpub)
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path,

        # old version of the assembly
        [Parameter()]
        [System.String]
        $oldVersion = '10.0.0.0',

        # new version to redirect to
        [Parameter()]
        [System.String]
        $newVersion = '6.3.0.0'
    )

    $webconfig = Join-Path $path 'web.config'

    if (Test-Path -Path $webconfig)
    {
        $xml = [System.Xml.XmlDocument] (Get-Content -Path $webconfig)

        if (-not($xml.get_DocumentElement().runtime))
        {
            # Create the <runtime> section
            $runtimeSetting = $xml.CreateElement('runtime')

            # Create the <assemblyBinding> section
            $assemblyBindingSetting = $xml.CreateElement('assemblyBinding')
            $xmlnsAttribute = $xml.CreateAttribute('xmlns')
            $xmlnsAttribute.Value = 'urn:schemas-microsoft-com:asm.v1'
            $assemblyBindingSetting.Attributes.Append($xmlnsAttribute)

            # The <assemblyBinding> section goes inside <runtime>
            $null = $runtimeSetting.AppendChild($assemblyBindingSetting)

            # Create the <dependentAssembly> section
            $dependentAssemblySetting = $xml.CreateElement('dependentAssembly')

            # The <dependentAssembly> section goes inside <assemblyBinding>
            $null = $assemblyBindingSetting.AppendChild($dependentAssemblySetting)

            # Create the <assemblyIdentity> section
            $assemblyIdentitySetting = $xml.CreateElement('assemblyIdentity')
            $nameAttribute = $xml.CreateAttribute('name')
            $nameAttribute.Value = 'microsoft.isam.esent.interop'
            $publicKeyTokenAttribute = $xml.CreateAttribute('publicKeyToken')
            $publicKeyTokenAttribute.Value = '31bf3856ad364e35'
            $null = $assemblyIdentitySetting.Attributes.Append($nameAttribute)
            $null = $assemblyIdentitySetting.Attributes.Append($publicKeyTokenAttribute)

            # <assemblyIdentity> section goes inside <dependentAssembly>
            $dependentAssemblySetting.AppendChild($assemblyIdentitySetting)

            # Create the <bindingRedirect> section
            $bindingRedirectSetting = $xml.CreateElement('bindingRedirect')
            $oldVersionAttribute = $xml.CreateAttribute('oldVersion')
            $newVersionAttribute = $xml.CreateAttribute('newVersion')
            $oldVersionAttribute.Value = $oldVersion
            $newVersionAttribute.Value = $newVersion
            $null = $bindingRedirectSetting.Attributes.Append($oldVersionAttribute)
            $null = $bindingRedirectSetting.Attributes.Append($newVersionAttribute)

            # The <bindingRedirect> section goes inside <dependentAssembly> section
            $dependentAssemblySetting.AppendChild($bindingRedirectSetting)

            # The <runtime> section goes inside <Configuration> section
            $xml.configuration.AppendChild($runtimeSetting)

            $xml.Save($webconfig)
        }
    }
}

$script:localizedData = Get-LocalizedData -ResourceName 'xPSDesiredStateConfiguration.Common' -ScriptRoot $PSScriptRoot

Export-ModuleMember -Function @(
        'Test-IsNanoServer',
        'Test-DscParameterState',
        'New-InvalidArgumentException',
        'New-InvalidOperationException',
        'New-ObjectNotFoundException',
        'New-InvalidResultException',
        'New-NotImplementedException',
        'Get-LocalizedData',
        'Set-DscMachineRebootRequired',
        'New-ResourceSetConfigurationScriptBlock',
        'New-PSWSEndpoint',
        'Set-AppSettingsInWebconfig',
        'Set-BindingRedirectSettingInWebConfig',
        'Remove-PSWSEndpoint'
    ) -Variable @(
        'DscWebServiceDefaultAppPoolName'
    )
