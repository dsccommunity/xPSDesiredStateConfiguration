#region localizeddata
if (Test-Path "${PSScriptRoot}\${PSUICulture}")
{
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename MSFT_xServiceResource.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\${PSUICulture}"
}
else
{
    #fallback to en-US
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename MSFT_xServiceResource.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\en-US"
}
#endregion

<#
    .SYNOPSIS
    Get the current status of a service.

    .PARAMETER name
    Indicates the service name. Note that sometimes this is different from the display name. You can get a list of the services and their current state with the Get-Service cmdlet.
#>
function Get-TargetResource
{
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name
    )

    if (Test-ServiceExists -Name $Name -ErrorAction SilentlyContinue)
    {
        $service = Get-ServiceResource -Name $Name
        $win32ServiceObject = Get-Win32ServiceObject -Name $Name

        $builtInAccount = $null

        if ($win32ServiceObject.StartName -ieq "LocalSystem")
        {
            $builtInAccount ="LocalSystem"
        }
        elseif ($win32ServiceObject.StartName -ieq "NT Authority\NetworkService")
        {
            $builtInAccount = "NetworkService"
        }
        elseif ($win32ServiceObject.StartName -ieq "NT Authority\LocalService")
        {
            $builtInAccount = "LocalService"
        }

        $dependencies = @()

        foreach ($serviceDependedOn in $service.ServicesDependedOn)
        {
            $dependencies += $serviceDependedOn.Name.ToString()
        }
        return @{
            Name            = $service.Name
            StartupType     = ConvertTo-StartupTypeString -StartupType $win32ServiceObject.StartMode
            BuiltInAccount  = $builtInAccount
            State           = $service.Status.ToString()
            Path            = $win32ServiceObject.PathName
            DisplayName     = $service.DisplayName
            Description     = $win32ServiceObject.Description
            DesktopInteract = $win32ServiceObject.DesktopInteract
            Dependencies    = $dependencies
            Ensure          = 'Present'
        }
    }
    else
    {
        return @{
            Name            = $service.Name
            Ensure          = 'Absent'
        }
    }
} # function Get-TargetResource

<#
    .SYNOPSIS
    Tests if a service needs to be created, changed or removed.

    .PARAMETER name
    Indicates the service name. Note that sometimes this is different from the display name.
    You can get a list ofthe services and their current state with the Get-Service cmdlet. Key.

    .PARAMETER Ensure
    Ensures that the service is present or absent. Optional. Defaults to Present.

    .PARAMETER Path
    The path to the service executable file. Optional.

    .PARAMETER StartupType
    Indicates the startup type for the service. Optional.

    .PARAMETER BuiltInAccount
    Indicates the sign-in account to use for the service. Optional.

    .PARAMETER Credential
    The credential to run the service under. Optional.

    .PARAMETER DesktopInteract
    The service can create or communicate with a window on the desktop. Must be false for services
    not running as LocalSystem. Optional. Defaults to False.

    .PARAMETER State
    Indicates the state you want to ensure for the service. Optional. Defaults to Running.

    .PARAMETER DisplayName
    The display name of the service. Optional.

    .PARAMETER Description
    The description of the service. Optional.

    .PARAMETER Dependencies
    An array of strings indicating the names of the dependencies of the service. Optional.

    .PARAMETER StartupTimeout
    The time to wait for the service to start in milliseconds. Optional.

    .PARAMETER TerminateTimeout
    The time to wait for the service to stop in milliseconds. Optional.
#>
function Test-TargetResource
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [ValidateSet("Automatic", "Manual", "Disabled")]
        [String]
        $StartupType,

        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        [String]
        $BuiltInAccount,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Boolean]
        $DesktopInteract,

        [ValidateSet("Running", "Stopped")]
        [String]
        $State = "Running",

        [ValidateSet("Present", "Absent")]
        [String]
        $Ensure = "Present",

        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [ValidateNotNullOrEmpty()]
        [String]
        $DisplayName,

        [ValidateNotNull()]
        [String]
        $Description,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Dependencies,

        [uint32]
        $StartupTimeout = 30000,

        [uint32]
        $TerminateTimeout = 30000
    )

    if ($PSBoundParameters.ContainsKey('StartupType'))
    {
        Test-StartupType -Name $Name -StartupType $StartupType -State $State
    } # if

    $serviceExists = Test-ServiceExists -Name $Name -ErrorAction SilentlyContinue

    if ($Ensure -eq 'Absent')
    {
        return -not $serviceExists
    } # if

    if (-not $serviceExists)
    {
        return $false
    } # if

    $svc = Get-TargetResource -Name $Name
    $svcWmi = Get-Win32ServiceObject -Name $Name

    # Check the binary path
    if ($PSBoundParameters.ContainsKey("Path") `
        -and -not (Compare-ServicePath -Name $Name -Path $Path))
    {
        Write-Verbose -Message ($LocalizedData.TestBinaryPathMismatch `
            -f $svcWmi.Name, $svcWmi.PathName, $Path)
        return $false
    } # if

    # Check the optional parameters
    if ($PSBoundParameters.ContainsKey("StartupType") `
        -or $PSBoundParameters.ContainsKey("BuiltInAccount") `
        -or $PSBoundParameters.ContainsKey("Credential") `
        -or $PSBoundParameters.ContainsKey("DesktopInteract"))
    {
        $getUserNameAndPasswordArgs = @{}
        if($PSBoundParameters.ContainsKey("BuiltInAccount"))
        {
            $null = $getUserNameAndPasswordArgs.Add("BuiltInAccount",$BuiltInAccount)
        } # if

        if($PSBoundParameters.ContainsKey("Credential"))
        {
            $null = $getUserNameAndPasswordArgs.Add("Credential",$Credential)
        } # if

        $userName,$password = Get-UserNameAndPassword @getUserNameAndPasswordArgs
        if($userName -ne $null -and !(Test-UserName -SvcWmi $SvcWmi -Username $userName))
        {
            Write-Verbose -Message ($LocalizedData.TestUserNameMismatch `
                -f $svcWmi.Name,$svcWmi.StartName,$userName)
            return $false
        } # if

        if ($PSBoundParameters.ContainsKey("DesktopInteract") `
            -and $SvcWmi.DesktopInteract -ne $DesktopInteract)
        {
            Write-Verbose -Message ($LocalizedData.TestDesktopInteractMismatch `
                -f $svcWmi.Name,$svcWmi.DesktopInteract,$DesktopInteract)
            return $false
        } # if

        if ($PSBoundParameters.ContainsKey("StartupType") `
            -and $SvcWmi.StartMode -ine (ConvertTo-StartModeString -StartupType $StartupType))
        {
            Write-Verbose -Message ($LocalizedData.TestStartupTypeMismatch `
                -f $svcWmi.Name,$svcWmi.StartMode,$StartupType)
            return $false
        } # if
    } # if

    if ($State -ne $svc.State)
    {
        Write-Verbose -Message ($LocalizedData.TestStateMismatch `
            -f $svcWmi.Name, $svc.State, $State)
        return $false
    } # if

    return $true
} # function Test-TargetResource

<#
    .SYNOPSIS
    Creates, updates or removes a service.

    .PARAMETER name
    Indicates the service name. Note that sometimes this is different from the display name.
    You can get a list ofthe services and their current state with the Get-Service cmdlet. Key.

    .PARAMETER Ensure
    Ensures that the service is present or absent. Optional. Defaults to Present.

    .PARAMETER Path
    The path to the service executable file. Optional.

    .PARAMETER StartupType
    Indicates the startup type for the service. Optional.

    .PARAMETER BuiltInAccount
    Indicates the sign-in account to use for the service. Optional.

    .PARAMETER Credential
    The credential to run the service under. Optional.

    .PARAMETER DesktopInteract
    The service can create or communicate with a window on the desktop. Must be false for services
    not running as LocalSystem. Optional. Defaults to False.

    .PARAMETER State
    Indicates the state you want to ensure for the service. Optional. Defaults to Running.

    .PARAMETER DisplayName
    The display name of the service. Optional.

    .PARAMETER Description
    The description of the service. Optional.

    .PARAMETER Dependencies
    An array of strings indicating the names of the dependencies of the service. Optional.

    .PARAMETER StartupTimeout
    The time to wait for the service to start in milliseconds. Optional.

    .PARAMETER TerminateTimeout
    The time to wait for the service to stop in milliseconds. Optional.
#>
function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [ValidateSet("Automatic", "Manual", "Disabled")]
        [String]
        $StartupType,

        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        [String]
        $BuiltInAccount,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Boolean]
        $DesktopInteract,

        [ValidateSet("Running", "Stopped")]
        [String]
        $State = "Running",

        [ValidateSet("Present", "Absent")]
        [String]
        $Ensure = "Present",

        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [ValidateNotNullOrEmpty()]
        [String]
        $DisplayName,

        [ValidateNotNull()]
        [String]
        $Description,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Dependencies,

        [uint32]
        $StartupTimeout = 30000,

        [uint32]
        $TerminateTimeout = 30000
    )

    if ($PSBoundParameters.ContainsKey('StartupType'))
    {
        Test-StartupType -Name $Name -StartupType $StartupType -State $State
    }

    if ($Ensure -eq "Absent")
    {
        Stop-ServiceResource -Name $Name -TerminateTimeout $TerminateTimeout
        Remove-Service $Name
        return
    }

    $serviceExists = Test-ServiceExists -Name $Name -ErrorAction SilentlyContinue
    $serviceIsNew = $false

    if ($PSBoundParameters.ContainsKey("Path") -and $serviceExists)
    {
        if (-not (Compare-ServicePath -Name $Name -Path $Path))
        {
            # Update the path
        }
    }
    elseif ($PSBoundParameters.ContainsKey("Path") -and -not $serviceExists)
    {
        $argumentsToNewService = @{}
        $argumentsToNewService.Add("Name", $Name)
        $argumentsToNewService.Add("BinaryPathName", $Path)
        if($PSBoundParameters.ContainsKey("Credential"))
        {
            $argumentsToNewService.Add("Credential", $Credential)
        }
        if($PSBoundParameters.ContainsKey("StartupType"))
        {
            $argumentsToNewService.Add("StartupType", $StartupType)
        }
        if($PSBoundParameters.ContainsKey("DisplayName"))
        {
            $argumentsToNewService.Add("DisplayName", $DisplayName)
        }
        if($PSBoundParameters.ContainsKey("Description"))
        {
            $argumentsToNewService.Add("Description", $Description)
        }
        if($PSBoundParameters.ContainsKey("Dependencies"))
        {
            $argumentsToNewService.Add("DependsOn", $Dependencies)
        }

        try
        {
            New-Service @argumentsToNewService
            $serviceIsNew = $true
        }
        catch
        {
            Write-Verbose -Message ($LocalizedData.TestStartupTypeMismatch `
                -f $argumentsToNewService["Name"], $_.Exception.Message)
            throw $_
        }
    }
    elseif (-not $PSBoundParameters.ContainsKey("Path") -and -not $serviceExists)
    {
        throw $LocalizedData.ServiceNotExists -f $Name
    }

    $svc = Get-TargetResource -Name $Name

    if (-not $serviceIsNew)
    {
       Write-Verbose -Message ($LocalizedData.WritePropertiesIgnored -f $Name)
    }

    $writeWritePropertiesArguments = @{
        Name = $Name
    }

    if ($PSBoundParameters.ContainsKey('Path'))
    {
        $writeWritePropertiesArguments['Path'] = $Path
    }

    if ($PSBoundParameters.ContainsKey('StartupType'))
    {
        $writeWritePropertiesArguments['StartupType'] = $StartupType
    }

    if ($PSBoundParameters.ContainsKey('BuiltInAccount'))
    {
        $writeWritePropertiesArguments['BuiltInAccount'] = $BuiltInAccount
    }

    if ($PSBoundParameters.ContainsKey('Credential'))
    {
        $writeWritePropertiesArguments['Credential'] = $Credential
    }

    if ($PSBoundParameters.ContainsKey('DesktopInteract'))
    {
        Write-Verbose -Verbose "DESKTOPINTERACTION FOR THE WINNNNNNNNNN"
        $writeWritePropertiesArguments['DesktopInteract'] = $DesktopInteract
    }

    $requiresRestart = Write-WriteProperties @writeWritePropertiesArguments

    if ($State -eq "Stopped")
    {
        # Ensure service is stopped
        Stop-ServiceResource -Name $Name -TerminateTimeout $TerminateTimeout
    }
    elseif ($State -eq "Running")
    {
        # if the service needs to be restarted then go stop it first
        if ($requiresRestart)
        {
            Write-Verbose -Message ($LocalizedData.ServiceNeedsRestartMessage -f
                $Name)
            Stop-ServiceResource -Name $Name -TerminateTimeout $TerminateTimeout
        }
        Start-ServiceResource $Name -StartupTimeout $StartupTimeout
    }
} # function Set-TargetResource

<#
    .SYNOPSIS
    Tests if the given StartupType with valid with the given State parameter for the service with the given name.

    .PARAMETER Name
    The name of the service for which to check the StartupType and State
    (For error message only)

    .PARAMETER StartupType
    The StartupType to test.

    .PARAMETER State
    The State to test against.
#>
function Test-StartupType
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        [String]
        $StartupType,

        [ValidateSet("Running", "Stopped")]
        [String]
        $State = "Running"
    )

    if ($State -eq "Stopped")
    {
        if ($StartupType -eq "Automatic")
        {
            # State = Stopped conflicts with Automatic or Delayed
            New-InvalidArgumentError `
                -ErrorId "CannotStopServiceSetToStartAutomatically" `
                -ErrorMessage ($LocalizedData.CannotStopServiceSetToStartAutomatically -f $Name)
        }
    }
    else
    {
        if ($StartupType -eq "Disabled")
        {
            # State = Running conflicts with Disabled
            New-InvalidArgumentError `
                -ErrorId "CannotStartAndDisable" `
                -ErrorMessage ($LocalizedData.CannotStartAndDisable -f $Name)
        }
    }
} # function Test-StartupType

<#
    .SYNOPSIS
    Converts the StartupType string to the correct StartMode string returned in the Win32
    service object.

    .PARAMETER StartupType
    The StartupType to convert.
#>
function ConvertTo-StartModeString
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Automatic', 'Manual', 'Disabled')]
        [String] $StartupType
    )

    if ($StartupType -ieq 'Automatic')
    {
        return 'Auto'
    }
    return $StartupType
} # function ConvertTo-StartModeString

<#
    .SYNOPSIS
    Converts the StartupType string returned in a Win32_Service object to the format
    expected by this resource.

    .PARAMETER StartupType
    The StartupType string to convert.
#>
function ConvertTo-StartupTypeString
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Auto', 'Manual', 'Disabled')]
        $StartupType
    )
    if ($StartupType -ieq 'Auto')
    {
        return "Automatic"
    } # if
    return $StartupType
} # function ConvertTo-StartupTypeString

<#
    .SYNOPSIS
    Writes all write properties if not already correctly set, logging errors and respecting whatif
#>
function Write-WriteProperties
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Name,

        [System.String]
        [ValidateNotNullOrEmpty()]
        $Path,

        [System.String]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        $StartupType,

        [System.String]
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        $BuiltInAccount,

        [System.Management.Automation.PSCredential]
        [ValidateNotNull()]
        $Credential,

        [Boolean]
        $DesktopInteract
    )

    $svcWmi = Get-Win32ServiceObject -Name $Name
    $requiresRestart = $false

    # update binary path
    if ($PSBoundParameters.ContainsKey('Path'))
    {
        $writeBinaryArguments = @{
            SvcWmi = $svcWmi
            Path = $Path
        }

        $requiresRestart = $requiresRestart -or (Write-BinaryProperties @writeBinaryArguments)
    }

    # update credentials
    if($PSBoundParameters.ContainsKey("BuiltInAccount") `
        -or $PSBoundParameters.ContainsKey("Credential"))
    {
        $writeCredentialPropertiesArguments=@{"SvcWmi"=$svcWmi}

        if($PSBoundParameters.ContainsKey("BuiltInAccount"))
        {
            $null=$writeCredentialPropertiesArguments.Add("BuiltInAccount",$BuiltInAccount)
        }

        if($PSBoundParameters.ContainsKey("Credential"))
        {
            $null=$writeCredentialPropertiesArguments.Add("Credential",$Credential)
        }

        if($PSBoundParameters.ContainsKey("DesktopInteract"))
        {
            $null=$writeCredentialPropertiesArguments.Add("DesktopInteract",$DesktopInteract)
        }

        Write-CredentialProperties @writeCredentialPropertiesArguments
    }

    # Update startup type
    if($PSBoundParameters.ContainsKey("StartupType"))
    {
        Set-ServiceStartupType -Win32ServiceObject $svcWmi -StartupType $StartupType
    }

    # Return restart status
    return $requiresRestart
} # function Write-WriteProperties

<#
    .SYNOPSIS
    Retrieves the Win32_Service object for the service with the given name.

    .PARAMETER Name
    The name of the service for which to get the Win32_Service object
#>
function Get-Win32ServiceObject
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        $Name
    )

    try
    {
        return Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'"
    }
    catch
    {
        Write-Verbose -Message ($LocalizedData.ErrorRetrievingServiceInformation `
            -f $Name,$_.Exception.Message)
        throw
    }
} # function Get-Win32ServiceObject

<#
    .SYNOPSIS
    Sets the StartupType property of the given service to the given value.

    .PARAMETER Win32ServiceObject
    The Win32_Service object for which to set the StartupType

    .PARAMETER StartupType
    The StartupType to set
#>
function Set-ServiceStartupType
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Win32ServiceObject,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        [String]
        $StartupType
    )

    if ($Win32ServiceObject.StartMode -ine $StartupType `
        -and $PSCmdlet.ShouldProcess($Win32ServiceObject.Name, $LocalizedData.SetStartupTypeWhatIf))
    {
        $changeServiceArguments = @{
            StartMode = $StartupType
        }

        $changeResult = Invoke-CimMethod `
            -InputObject $Win32ServiceObject `
            -MethodName Change `
            -Arguments $changeServiceArguments

        if ($changeResult.ReturnValue -ne 0)
        {
            $methodFailedMessage = ($LocalizedData.MethodFailed `
                -f "Change", "Win32_Service", $changeResult.ReturnValue)
            $errorChangingPropertyMessage = ($LocalizedData.ErrorChangingProperty `
                -f "StartupType", $innerMessage)
            New-InvalidArgumentError `
                -ErrorId "ChangeStartupTypeFailed" `
                -ErrorMessage $errorChangingPropertyMessage
        }
    }
} # function Set-ServiceStartupType

<#
    .SYNOPSIS
    Writes credential properties if not already correctly set, logging errors and respecting whatif
#>
function Write-CredentialProperties
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $SvcWmi,

        [System.String]
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        $BuiltInAccount,

        [System.Management.Automation.PSCredential]
        $Credential,

        [Boolean]
        $DesktopInteract
    )

    if(-not $PSBoundParameters.ContainsKey("Credential") `
        -and -not $PSBoundParameters.ContainsKey("BuiltInAccount"))
    {
        return
    } # if

    if($PSBoundParameters.ContainsKey("Credential") `
        -and $PSBoundParameters.ContainsKey("BuiltInAccount"))
    {
        New-InvalidArgumentError `
            -ErrorId "OnlyCredentialOrBuiltInAccount" `
            -ErrorMessage ($LocalizedData.OnlyOneParameterCanBeSpecified `
                -f "Credential","BuiltInAccount")
    } # if

    $getUserNameAndPasswordArgs=@{}
    if($PSBoundParameters.ContainsKey("BuiltInAccount"))
    {
        $null = $getUserNameAndPasswordArgs.Add("BuiltInAccount",$BuiltInAccount)
    } # if

    if($PSBoundParameters.ContainsKey("Credential"))
    {
        $null = $getUserNameAndPasswordArgs.Add("Credential",$Credential)
    } # if

    $userName,$password = Get-UserNameAndPassword @getUserNameAndPasswordArgs

    if($null -ne $userName `
        -and -not (Test-UserName -SvcWmi $SvcWmi -Username $userName) `
        -and $PSCmdlet.ShouldProcess($SvcWmi.Name,$LocalizedData.SetCredentialWhatIf))
    {
        if($PSBoundParameters.ContainsKey("Credential"))
        {
            Set-LogOnAsServicePolicy $userName
        } # if

        $arguments = @{
            StartName = $userName
            StartPassword = $password
        }

        if($PSBoundParameters.ContainsKey("DesktopInteract"))
        {
            $arguments.DesktopInteract = $DesktopInteract
        } # if

        $ret = Invoke-CimMethod `
            -InputObject $SvcWmi `
            -MethodName Change `
            -Arguments $arguments
        if($ret.ReturnValue -ne 0)
        {
            $innerMessage = ($LocalizedData.MethodFailed `
                -f "Change","Win32_Service",$ret.ReturnValue)
            $message = ($LocalizedData.ErrorChangingProperty `
                -f "Credential",$innerMessage)
            New-InvalidArgumentError `
                -ErrorId "ChangeCredentialFailed" `
                -ErrorMessage $message
        } # if
    } # if
} # function Write-CredentialProperties

<#
    .SYNOPSIS
    Writes binary path if not already correctly set, logging errors and respecting whatif
#>
function Write-BinaryProperties
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $SvcWmi,

        [System.String]
        [ValidateNotNullOrEmpty()]
        $Path
    )

    if($SvcWmi.PathName -eq $Path)
    {
        return $false
    }

    $ret = $SvcWmi.Change($null, $Path, $null, $null, $null, $null, $null, $null)
    if($ret.ReturnValue -ne 0)
    {
        $innerMessage = $LocalizedData.MethodFailed -f "Change","Win32_Service",$ret.ReturnValue
        $message = $LocalizedData.ErrorChangingProperty -f "Binary Path",$innerMessage
        New-InvalidArgumentError `
            -ErrorId "ChangeBinaryPathFailed" `
            -ErrorMessage $message
    }

    return $true
} # function Write-BinaryProperties

<#
    .SYNOPSIS
    Returns true if the service's StartName matches $UserName
#>
function Test-UserName
{
    param
    (
        $SvcWmi,

        [string]
        $UserName
    )

    return  (Resolve-UserName -UserName $SvcWmi.StartName) -ieq $UserName
} # function Test-UserName

<#
    .SYNOPSIS
    Retrieves username and password out of the BuiltInAccount and Credential parameters

    .PARAMETER BuiltInAccount
    If passed the username will contain the resolved username for the built-in account.

    .PARAMETER Credential
    The Credential to extract the username from.
#>
function Get-UserNameAndPassword
{
    param
    (
        [System.String]
        [ValidateSet("LocalSystem", "LocalService", "NetworkService")]
        $BuiltInAccount,

        [System.Management.Automation.PSCredential]
        $Credential
    )

    if($PSBoundParameters.ContainsKey("BuiltInAccount"))
    {
        return (Resolve-UserName -UserName $BuiltInAccount.ToString()),$null
    }

    if($PSBoundParameters.ContainsKey("Credential"))
    {
        return (Resolve-UserName -UserName $Credential.UserName),`
            $Credential.GetNetworkCredential().Password
    }

    return $null,$null
} # function Get-UserNameAndPassword

<#
    .SYNOPSIS
    Stops a service if it is not already stopped.

    .PARAMETER Name
    The name of the service to stop.

    .PARAMETER TerminateTimeout
    The amount of time to wait for the service to stop.
#>
function Stop-ServiceResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [uint32]
        $TerminateTimeout
    )

    $service = Get-ServiceResource -Name $Name

    if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped)
    {
        Write-Verbose -Message ($LocalizedData.ServiceAlreadyStopped -f $service.Name)
        return
    }

    if ($PSCmdlet.ShouldProcess($Name, $LocalizedData.StopServiceWhatIf))
    {
        try
        {
            $service.Stop()
            $waitTimeSpan = New-Object `
                -TypeName TimeSpan `
                -ArgumentList ($TerminateTimeout * 10000)
            $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped,`
                $waitTimeSpan)
        }
        catch
        {
            Write-Verbose -Message ($LocalizedData.ErrorStoppingService `
                -f $service.Name, $_.Exception.Message)
            throw
        }

        Write-Verbose -Message ($LocalizedData.ServiceStopped -f $service.Name)
    }
} # function Stop-ServiceResource

<#
    .SYNOPSIS
    Deletes a service

    .PARAMETER Name
    The name of the service to delete.
#>
function Remove-Service
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Name
    )

    $err = & "sc.exe" "delete" "$Name"
    for($i = 1; $i -lt 1000; $i++)
    {
        if(-not (Test-ServiceExists -Name $Name))
        {
            $serviceDeletedSuccessfully = $true
            break
        } # if
        #try again after 2 millisecs if the service is not deleted.
        Write-Verbose -Message ($LocalizedData.TryDeleteAgain)
        Start-Sleep -Seconds .002
    } # for
    if (-not $serviceDeletedSuccessfully)
    {
        $errorMessage = ($LocalizedData.ErrorDeletingService -f $Name)
        New-InvalidArgumentError `
            -ErrorId "ErrorDeletingService" `
            -ErrorMessage $errorMessage
    }
    else
    {
        Write-Verbose -Message ($LocalizedData.ServiceDeletedSuccessfully -f $Name)
    } # if
} # function Remove-Service

<#
    .SYNOPSIS
    Starts a service if it is not already running.

    .PARAMETER Name
    The name of the service to start.

    .PARAMETER StartupTimeout
    The amount of time to wait for the service to start.
#>
function Start-ServiceResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [uint32]
        $StartupTimeout
    )

    $service = Get-ServiceResource -Name $Name

    if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)
    {
        Write-Verbose -Message ($LocalizedData.ServiceAlreadyStarted -f $service.Name)
        return
    } # if

    if ($PSCmdlet.ShouldProcess($Name, $LocalizedData.StartServiceWhatIf))
    {
        try
        {
            $service.Start()
            $waitTimeSpan = New-Object `
                -TypeName TimeSpan `
                -ArgumentList ($StartupTimeout * 10000)
            $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,`
                $waitTimeSpan)
        }
        catch
        {
            $servicePath = (Get-CimInstance -Class win32_service |
                Where-Object {$_.Name -eq $Name}).PathName
            $errorMessage = ($LocalizedData.ErrorStartingService -f `
                $service.Name, $servicePath, $_.Exception.Message)
            New-InvalidArgumentError `
                -ErrorId "ErrorStartingService" `
                -ErrorMessage $errorMessage
        } # try

        Write-Verbose -Message ($LocalizedData.ServiceStarted -f $service.Name)
    } # if
} # function Start-ServiceResource

<#
    .SYNOPSIS
    Converts the username returned in a Win32_service object to the format
    expected by this resource.

    .PARAMETER UserName
    The Username to convert.
#>

function Resolve-UserName
{
    param
    (
        [String]
        $UserName
    )
    switch ($Username)
    {
        'NetworkService'
        {
            return "NT Authority\NetworkService"
        } # 'NetworkService'
        'LocalService'
        {
            return "NT Authority\LocalService"
        } # 'LocalService'
        'LocalSystem'
        {
            return ".\LocalSystem"
        } # 'LocalSystem'
        default
        {
            if ($UserName.IndexOf("\") -eq -1)
            {
                return ".\" + $UserName
            } # if
        } # default
    } # switch
    return $UserName
} # function Resolve-UserName

<#
    .SYNOPSIS
    Throws an argument error.

    .PARAMETER ErrorId
    The error id to assign to the custom exception.

    .PARAMETER ErrorMessage
    The error message to assign to the custom exception.
#>
function New-InvalidArgumentError
{
    [CmdletBinding()]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorMessage
    )

    $errorCategory=[System.Management.Automation.ErrorCategory]::InvalidArgument
    $exception = New-Object `
        -TypeName System.ArgumentException `
        -ArgumentList $ErrorMessage
    $errorRecord = New-Object `
        -TypeName System.Management.Automation.ErrorRecord `
        -ArgumentList $exception, $ErrorId, $errorCategory, $null
    throw $errorRecord
} # function New-InvalidArgumentError

<#
    .SYNOPSIS
    Tests if a service with the given name exists

    .PARAMETER Name
    The name of the service to test for.
#>
function Test-ServiceExists
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name
    )

    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    return $null -ne $service
} # function Test-ServiceExists

<#
    .SYNOPSIS
    Compares a path to the existing service path.
    Returns true when the given path is same as the existing service path.

    .PARAMETER Name
    The name of the existing service for which to check the path.

    .PARAMETER Path
    The path to check against.
#>
function Compare-ServicePath
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path
    )

    $existingServicePath = (Get-CimInstance -Class win32_service |
        Where-Object {$_.Name -eq $Name}).PathName
    $stringCompareResult = [String]::Compare($Path, `
        $existingServicePath, `
        [System.Globalization.CultureInfo]::CurrentUICulture)

    return $stringCompareResult -eq 0
} # function Compare-ServicePath

<#
    .SYNOPSIS
    Retrieves the service with the given name.

    .PARAMETER Name
    The name of the service to retrieve
#>
function Get-ServiceResource
{
    [CmdletBinding()]
    param
    (

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name
    )

    $service = Get-Service -Name $Name -ErrorAction Ignore
    if ($null -eq $service)
    {
        New-InvalidArgumentError `
            -ErrorId "ServiceNotFound" `
            -ErrorMessage ($LocalizedData.ServiceNotFound -f $Name)
    } # if

    return $service
} # function Get-ServiceResource

<#
    .SYNOPSIS
    Grants log on as service right to the given user
#>
function Set-LogOnAsServicePolicy
{
    param
    (
        [String]
        $UserName
    )

    $logOnAsServiceText=@"
        namespace LogOnAsServiceHelper
        {
            using Microsoft.Win32.SafeHandles;
            using System;
            using System.Runtime.ConstrainedExecution;
            using System.Runtime.InteropServices;
            using System.Security;

            public class NativeMethods
            {
                #region constants
                // from ntlsa.h
                private const int POLICY_LOOKUP_NAMES = 0x00000800;
                private const int POLICY_CREATE_ACCOUNT = 0x00000010;
                private const uint ACCOUNT_ADJUST_SYSTEM_ACCESS = 0x00000008;
                private const uint ACCOUNT_VIEW = 0x00000001;
                private const uint SECURITY_ACCESS_SERVICE_LOGON = 0x00000010;

                // from LsaUtils.h
                private const uint STATUS_OBJECT_NAME_NOT_FOUND = 0xC0000034;

                // from lmcons.h
                private const int UNLEN = 256;
                private const int DNLEN = 15;

                // Extra characteres for "\","@" etc.
                private const int EXTRA_LENGTH = 3;
                #endregion constants

                #region interop structures
                /// <summary>
                /// Used to open a policy, but not containing anything meaqningful
                /// </summary>
                [StructLayout(LayoutKind.Sequential)]
                private struct LSA_OBJECT_ATTRIBUTES
                {
                    public UInt32 Length;
                    public IntPtr RootDirectory;
                    public IntPtr ObjectName;
                    public UInt32 Attributes;
                    public IntPtr SecurityDescriptor;
                    public IntPtr SecurityQualityOfService;

                    public void Initialize()
                    {
                        this.Length = 0;
                        this.RootDirectory = IntPtr.Zero;
                        this.ObjectName = IntPtr.Zero;
                        this.Attributes = 0;
                        this.SecurityDescriptor = IntPtr.Zero;
                        this.SecurityQualityOfService = IntPtr.Zero;
                    }
                }

                /// <summary>
                /// LSA string
                /// </summary>
                [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
                private struct LSA_UNICODE_STRING
                {
                    internal ushort Length;
                    internal ushort MaximumLength;
                    [MarshalAs(UnmanagedType.LPWStr)]
                    internal string Buffer;

                    internal void Set(string src)
                    {
                        this.Buffer = src;
                        this.Length = (ushort)(src.Length * sizeof(char));
                        this.MaximumLength = (ushort)(this.Length + sizeof(char));
                    }
                }

                /// <summary>
                /// Structure used as the last parameter for LSALookupNames
                /// </summary>
                [StructLayout(LayoutKind.Sequential)]
                private struct LSA_TRANSLATED_SID2
                {
                    public uint Use;
                    public IntPtr SID;
                    public int DomainIndex;
                    public uint Flags;
                };
                #endregion interop structures

                #region safe handles
                /// <summary>
                /// Handle for LSA objects including Policy and Account
                /// </summary>
                private class LsaSafeHandle : SafeHandleZeroOrMinusOneIsInvalid
                {
                    [DllImport("advapi32.dll")]
                    private static extern uint LsaClose(IntPtr ObjectHandle);

                    /// <summary>
                    /// Prevents a default instance of the LsaPolicySafeHAndle class from being created.
                    /// </summary>
                    private LsaSafeHandle(): base(true)
                    {
                    }

                    /// <summary>
                    /// Calls NativeMethods.CloseHandle(handle)
                    /// </summary>
                    /// <returns>the return of NativeMethods.CloseHandle(handle)</returns>
                    [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
                    protected override bool ReleaseHandle()
                    {
                        long returnValue = LsaSafeHandle.LsaClose(this.handle);
                        return returnValue != 0;

                    }
                }

                /// <summary>
                /// Handle for IntPtrs returned from Lsa calls that have to be freed with
                /// LsaFreeMemory
                /// </summary>
                private class SafeLsaMemoryHandle : SafeHandleZeroOrMinusOneIsInvalid
                {
                    [DllImport("advapi32")]
                    internal static extern int LsaFreeMemory(IntPtr Buffer);

                    private SafeLsaMemoryHandle() : base(true) { }

                    private SafeLsaMemoryHandle(IntPtr handle)
                        : base(true)
                    {
                        SetHandle(handle);
                    }

                    private static SafeLsaMemoryHandle InvalidHandle
                    {
                        get { return new SafeLsaMemoryHandle(IntPtr.Zero); }
                    }

                    override protected bool ReleaseHandle()
                    {
                        return SafeLsaMemoryHandle.LsaFreeMemory(handle) == 0;
                    }

                    internal IntPtr Memory
                    {
                        get
                        {
                            return this.handle;
                        }
                    }
                }
                #endregion safe handles

                #region interop function declarations
                /// <summary>
                /// Opens LSA Policy
                /// </summary>
                [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
                private static extern uint LsaOpenPolicy(
                    IntPtr SystemName,
                    ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
                    uint DesiredAccess,
                    out LsaSafeHandle PolicyHandle
                );

                /// <summary>
                /// Convert the name into a SID which is used in remaining calls
                /// </summary>
                [DllImport("advapi32", CharSet = CharSet.Unicode, SetLastError = true), SuppressUnmanagedCodeSecurityAttribute]
                private static extern uint LsaLookupNames2(
                    LsaSafeHandle PolicyHandle,
                    uint Flags,
                    uint Count,
                    LSA_UNICODE_STRING[] Names,
                    out SafeLsaMemoryHandle ReferencedDomains,
                    out SafeLsaMemoryHandle Sids
                );

                /// <summary>
                /// Opens the LSA account corresponding to the user's SID
                /// </summary>
                [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
                private static extern uint LsaOpenAccount(
                    LsaSafeHandle PolicyHandle,
                    IntPtr Sid,
                    uint Access,
                    out LsaSafeHandle AccountHandle);

                /// <summary>
                /// Creates an LSA account corresponding to the user's SID
                /// </summary>
                [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
                private static extern uint LsaCreateAccount(
                    LsaSafeHandle PolicyHandle,
                    IntPtr Sid,
                    uint Access,
                    out LsaSafeHandle AccountHandle);

                /// <summary>
                /// Gets the LSA Account access
                /// </summary>
                [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
                private static extern uint LsaGetSystemAccessAccount(
                    LsaSafeHandle AccountHandle,
                    out uint SystemAccess);

                /// <summary>
                /// Sets the LSA Account access
                /// </summary>
                [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
                private static extern uint LsaSetSystemAccessAccount(
                    LsaSafeHandle AccountHandle,
                    uint SystemAccess);
                #endregion interop function declarations

                /// <summary>
                /// Sets the Log On As A Service Policy for <paramref name="userName"/>, if not already set.
                /// </summary>
                /// <param name="userName">the user name we want to allow logging on as a service</param>
                /// <exception cref="ArgumentNullException">If the <paramref name="userName"/> is null or empty.</exception>
                /// <exception cref="InvalidOperationException">In the following cases:
                ///     Failure opening the LSA Policy.
                ///     The <paramref name="userName"/> is too large.
                ///     Failure looking up the user name.
                ///     Failure opening LSA account (other than account not found).
                ///     Failure creating LSA account.
                ///     Failure getting LSA account policy access.
                ///     Failure setting LSA account policy access.
                /// </exception>
                public static void SetLogOnAsServicePolicy(string userName)
                {
                    if (String.IsNullOrEmpty(userName))
                    {
                        throw new ArgumentNullException("userName");
                    }

                    LSA_OBJECT_ATTRIBUTES objectAttributes = new LSA_OBJECT_ATTRIBUTES();
                    objectAttributes.Initialize();

                    // All handles are delcared in advance so they can be closed on finally
                    LsaSafeHandle policyHandle = null;
                    SafeLsaMemoryHandle referencedDomains = null;
                    SafeLsaMemoryHandle sids = null;
                    LsaSafeHandle accountHandle = null;

                    try
                    {
                        uint status = LsaOpenPolicy(
                            IntPtr.Zero,
                            ref objectAttributes,
                            POLICY_LOOKUP_NAMES | POLICY_CREATE_ACCOUNT,
                            out policyHandle);

                        if (status != 0)
                        {
                            throw new InvalidOperationException("CannotOpenPolicyErrorMessage");
                        }

                        // Unicode strings have a maximum length of 32KB. We don't want to create
                        // LSA strings with more than that. User lengths are much smaller so this check
                        // ensures userName's length is useful
                        if (userName.Length > UNLEN + DNLEN + EXTRA_LENGTH)
                        {
                            throw new InvalidOperationException("UserNameTooLongErrorMessage");
                        }

                        LSA_UNICODE_STRING lsaUserName = new LSA_UNICODE_STRING();
                        lsaUserName.Set(userName);

                        LSA_UNICODE_STRING[] names = new LSA_UNICODE_STRING[1];
                        names[0].Set(userName);

                        status = LsaLookupNames2(
                            policyHandle,
                            0,
                            1,
                            new LSA_UNICODE_STRING[] { lsaUserName },
                            out referencedDomains,
                            out sids);

                        if (status != 0)
                        {
                            throw new InvalidOperationException("CannotLookupNamesErrorMessage");
                        }

                        LSA_TRANSLATED_SID2 sid = (LSA_TRANSLATED_SID2)Marshal.PtrToStructure(sids.Memory, typeof(LSA_TRANSLATED_SID2));

                        status = LsaOpenAccount(policyHandle,
                                            sid.SID,
                                            ACCOUNT_VIEW | ACCOUNT_ADJUST_SYSTEM_ACCESS,
                                            out accountHandle);

                        uint currentAccess = 0;

                        if (status == 0)
                        {
                            status = LsaGetSystemAccessAccount(accountHandle, out currentAccess);

                            if (status != 0)
                            {
                                throw new InvalidOperationException("CannotGetAccountAccessErrorMessage");
                            }

                        }
                        else if (status == STATUS_OBJECT_NAME_NOT_FOUND)
                        {
                            status = LsaCreateAccount(
                                policyHandle,
                                sid.SID,
                                ACCOUNT_ADJUST_SYSTEM_ACCESS,
                                out accountHandle);

                            if (status != 0)
                            {
                                throw new InvalidOperationException("CannotCreateAccountAccessErrorMessage");
                            }
                        }
                        else
                        {
                            throw new InvalidOperationException("CannotOpenAccountErrorMessage");
                        }

                        if ((currentAccess & SECURITY_ACCESS_SERVICE_LOGON) == 0)
                        {
                            status = LsaSetSystemAccessAccount(
                                accountHandle,
                                currentAccess | SECURITY_ACCESS_SERVICE_LOGON);
                            if (status != 0)
                            {
                                throw new InvalidOperationException("CannotSetAccountAccessErrorMessage");
                            }
                        }
                    }
                    finally
                    {
                        if (policyHandle != null) { policyHandle.Close(); }
                        if (referencedDomains != null) { referencedDomains.Close(); }
                        if (sids != null) { sids.Close(); }
                        if (accountHandle != null) { accountHandle.Close(); }
                    }
                }
            }
        }
"@

    try
    {
        $existingType = [LogOnAsServiceHelper.NativeMethods]
    }
    catch
    {
        $logOnAsServiceText = $logOnAsServiceText.Replace("CannotOpenPolicyErrorMessage",`
            $LocalizedData.CannotOpenPolicyErrorMessage)
        $logOnAsServiceText = $logOnAsServiceText.Replace("UserNameTooLongErrorMessage",`
            $LocalizedData.UserNameTooLongErrorMessage)
        $logOnAsServiceText = $logOnAsServiceText.Replace("CannotLookupNamesErrorMessage",`
            $LocalizedData.CannotLookupNamesErrorMessage)
        $logOnAsServiceText = $logOnAsServiceText.Replace("CannotOpenAccountErrorMessage",`
            $LocalizedData.CannotOpenAccountErrorMessage)
        $logOnAsServiceText = $logOnAsServiceText.Replace("CannotCreateAccountAccessErrorMessage",`
            $LocalizedData.CannotCreateAccountAccessErrorMessage)
        $logOnAsServiceText = $logOnAsServiceText.Replace("CannotGetAccountAccessErrorMessage",`
            $LocalizedData.CannotGetAccountAccessErrorMessage)
        $logOnAsServiceText = $logOnAsServiceText.Replace("CannotSetAccountAccessErrorMessage",`
            $LocalizedData.CannotSetAccountAccessErrorMessage)
        $null = Add-Type $logOnAsServiceText -PassThru -Debug:$false
    } # try

    if($UserName.StartsWith(".\"))
    {
        $UserName = $UserName.Substring(2)
    } # if

    try
    {
        [LogOnAsServiceHelper.NativeMethods]::SetLogOnAsServicePolicy($UserName)
    }
    catch
    {
        $message = ($LocalizedData.ErrorSettingLogOnAsServiceRightsForUser `
            -f $UserName,$_.Exception.Message)
        New-InvalidArgumentError -ErrorId "ErrorSettingLogOnAsServiceRightsForUser" -ErrorMessage $message
    } # try
} # function Set-LogOnAsServicePolicy

Export-ModuleMember -Function *-TargetResource
