
Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonResourceHelper.psm1')

# Localized messages for Write-Verbose statements in this resource
$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_xWindowsFeature'

<#
    .SYNOPSIS
        Retrieves the status of the role or feature with the given name on the target machine.

    .PARAMETER Name
        The name of the Windows feature to retrieve

    .PARAMETER Credential
        Credential attributes (if required) to retrieve the info on the role or feature.
        Optional.

    .NOTES
        If a feature does not contain any subfeatures then $includeAllSubFeature
        will be set to $false. If a feature contains one or more subfeatures then
        $includeAllSubFeature will be set to $true only if all the subfeatures are installed
        otherwise, $includeAllSubFeature will be set to $false. 
#>
function Get-TargetResource
{
     [OutputType([Hashtable])]
     param
     (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
        
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
     )

        $getTargetResourceResult = $null
 
        Write-Verbose -Message ($script:localizedData.GetTargetResourceStartMessage-f ${Name})

        Assert-PrerequisitesValid 

        Write-Verbose -Message ($script:localizedData.QueryFeature -f ${Name})

        $isR2Sp1 = Test-IsWinServer2008R2SP1
        if ($isR2Sp1 -and $psboundparameters.ContainsKey('Credential'))
        {
            $parameters = $psboundparameters.Remove('Credential')
            $feature = Invoke-Command -ScriptBlock { Get-WindowsFeature @using:psboundparameters } `
                                      -ComputerName . `
                                      -Credential $Credential `
                                      -ErrorVariable ev
            $psboundparameters.Add('Credential', $Credential)
        }
        else
        {
            $feature = Get-WindowsFeature @psboundparameters -ErrorVariable ev
        }

        if ($null -eq $ev -or $ev.Count -eq 0)
        {
            $foundError = $false

            Assert-FeatureValid $feature $Name

            $includeAllSubFeature = $true

            if ($feature.SubFeatures.Count -eq 0)
            {
                $includeAllSubFeature = $false
            }
            else
            {
                foreach ($currentSubFeature in $feature.SubFeatures)
                {
                   if ($foundError -eq $false)
                   {
                        $parameters = $psboundparameters.Remove('Name')
                        $psboundparameters.Add('Name', $currentSubFeature)

                        $isR2Sp1 = Test-IsWinServer2008R2SP1
                        if ($isR2Sp1 -and $psboundparameters.ContainsKey('Credential'))
                        {
                            $parameters = $psboundparameters.Remove('Credential')
                            $subFeature = Invoke-Command -ScriptBlock { Get-WindowsFeature @using:psboundparameters } `
                                                         -ComputerName . `
                                                         -Credential $Credential `
                                                         -ErrorVariable errorVar
                            $psboundparameters.Add('Credential', $Credential)
                        }
                        else
                        {
                            $subFeature = Get-WindowsFeature @psboundparameters -ErrorVariable errorVar
                        }

                        if ($null -eq $errorVar -or $errorVar.Count -eq 0)
                        {
                            Assert-FeatureValid $subFeature $currentSubFeature

                            if (-not $subFeature.Installed)
                            {
                                $includeAllSubFeature = $false
                                break
                            }
                        }
                        else
                        {
                            $foundError = $true
                        }
                    }
                }
            }

            if ($foundError -eq $false)
            {
                if ($feature.Installed)
                {
                    $ensureResult = 'Present'
                }
                else
                {
                    $ensureResult = 'Absent'
                }

                # Add all feature properties to the hash table
                $getTargetResourceResult = @{
                    Name = $Name
                    DisplayName = $feature.DisplayName
                    Ensure = $ensureResult
                    IncludeAllSubFeature = $includeAllSubFeature
                }

                Write-Verbose -Message ($script:localizedData.GetTargetResourceEndMessage -f ${Name})

                return $getTargetResourceResult
            }
        }
}

<#
    .SYNOPSIS
        Installs or uninstalls the role or feature with the given name on the target machine.
        If IncludeAllSubFeature is set to $true, then all of the subfeatures of the given feature
        will also be installed. 

    .PARAMETER Name
        The name of the Windows feature to install or uninstall.

    .PARAMETER Ensure
        Specifies whether the feature should be installed ('Present') or uninstalled ('Absent').
        By default this is set to Present.

    .PARAMETER IncludeAllSubFeature
        Specifies whether the subfeatures of the indicated feature should also be installed.
        If Ensure is set to 'Absent' then all (if any) subfeatures will always be uninstalled
        as well.
        By default this is set to $false.

    .PARAMETER Credential
        Credential (if required) to install or uninstall the role or feature.
        Optional.

    .PARAMETER LogPath
        The custom path to the log file to log this operation.
        If not passed in, the default log path will be used.

#>
function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'FeatureName')]
    param
    (
       [parameter(Mandatory = $true, ParameterSetName = 'FeatureName')]
       [ValidateNotNullOrEmpty()]
       [String]
       $Name,

       [ValidateSet('Present', 'Absent')]
       [String]
       $Ensure = 'Present',

       [Boolean]
       $IncludeAllSubFeature = $false,

       [System.Management.Automation.PSCredential]
       [System.Management.Automation.Credential()]
       $Credential,

       [ValidateNotNullOrEmpty()]
       [String]
       $LogPath
    )

    Write-Verbose -Message ($script:localizedData.SetTargetResourceStartMessage -f ${Name})

    Assert-PrerequisitesValid 

    if ($Ensure -eq 'Present')
    {
        $parameters = $psboundparameters.Remove('Ensure')

        Write-Verbose -Message ($script:localizedData.InstallFeature -f ${Name})

        $isR2Sp1 = Test-IsWinServer2008R2SP1
        if ($isR2Sp1 -and $psboundparameters.ContainsKey('Credential'))
        {
            $parameters = $psboundparameters.Remove('Credential')
            $feature = Invoke-Command -ScriptBlock { Add-WindowsFeature @using:psboundparameters } `
                                      -ComputerName . `
                                      -Credential $Credential `
                                      -ErrorVariable ev
            $psboundparameters.Add('Credential', $Credential)
        }
        else
        {
            $feature = Add-WindowsFeature @psboundparameters -ErrorVariable ev
        }

        if ($null -ne $feature -and $feature.Success -eq $true)
        {
            Write-Verbose ($script:localizedData.InstallSuccess -f $Name)

            # Check if reboot is required, if so notify CA.
            if ($feature.RestartNeeded -eq 'Yes')
            {
                Write-Verbose -Message $script:localizedData.RestartNeeded

                $global:DSCMachineStatus = 1
            }
        }
        else
        {
            <#
                The Add-WindowsFeature cmdlet failed to successfully install the requested feature.
                If there are errors from the Add-WindowsFeature cmdlet. We surface those errors.
                If Add-WindwosFeature cmdlet does not surface any errors. Then the provider throws
                a terminating error.
            #>
            if ($null -eq $ev -or $ev.Count -eq 0)
            {
                $errorId = 'FeatureInstallationFailure'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                $errorMessage = $($script:localizedData.FeatureInstallationFailureError) -f ${Name} 
                $exception = New-Object System.InvalidOperationException $errorMessage 
                $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

                New-InvalidOperationException -Message $errorMessage -ErrorRecord $errorRecord
            }
        }
    }
    # Ensure = 'Absent'
    else
    {
        $parameters = $psboundparameters.Remove('Ensure')
        $parameters = $psboundparameters.Remove('IncludeAllSubFeature')

        Write-Verbose -Message ($script:localizedData.UninstallFeature -f ${Name})

        $isR2Sp1 = Test-IsWinServer2008R2SP1
        if ($isR2Sp1 -and $psboundparameters.ContainsKey('Credential'))
        {
            $parameters = $psboundparameters.Remove('Credential')
            $feature = Invoke-Command -ScriptBlock { Remove-WindowsFeature @using:psboundparameters } `
                                      -ComputerName . `
                                      -Credential $Credential `
                                      -ErrorVariable ev
            $psboundparameters.Add('Credential', $Credential)
        }
        else
        {
            $feature = Remove-WindowsFeature @psboundparameters -ErrorVariable ev
        }

        if ($feature -ne $null -and $feature.Success -eq $true)
        {
            Write-Verbose ($script:localizedData.UninstallSuccess -f $Name)

            # Check if reboot is required, if so notify CA.
            if ($feature.RestartNeeded -eq 'Yes')
            {
                Write-Verbose -Message $script:localizedData.RestartNeeded
                $global:DSCMachineStatus = 1
            }
        }
        else
        {
            <#
                The Remove-WindowsFeature cmdlet failed to successfully Uninstall the requested feature.
                If there are errors from the Remove-WindowsFeature cmdlet. We surface those errors.
                If Remove-WindwosFeature cmdlet does not surface any errors. Then the provider throws
                a terminating error.
            #>
            if ($null -eq $ev -or $ev.Count -eq 0)
            {
                $errorId = 'FeatureUninstallationFailure'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                $errorMessage = $($script:localizedData.FeatureUninstallationFailureError) -f ${Name} 
                $exception = New-Object System.InvalidOperationException $errorMessage 
                $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

                New-InvalidOperationException -Message $errorMessage -ErrorRecord $errorRecord
            }
        }
    }

    Write-Verbose -Message ($script:localizedData.SetTargetResourceEndMessage -f ${Name})
}

<#
    .SYNOPSIS
        Tests if the feature with the given name is in the desired state. 

    .PARAMETER Name
        The name of the Windows feature to test the state of.

    .PARAMETER Ensure
        Specifies whether the feature should be installed ('Present') or uninstalled ('Absent').
        By default this is set to Present.

    .PARAMETER IncludeAllSubFeature
        Specifies whether the subfeatures of the indicated feature should also be checked that
        they are in the desired state. If Ensure is set to 'Present' and this is set to $true
        then each subfeature is checked to ensure it is installed as well. If Ensure is set to
        Absent and this is set to $true, then each subfeature is checked to ensure it is uninstalled.
        As of now, this test can't be used to check if a feature is Installed but all of its
        subfeatures are uninstalled.
        By default this is set to $false.

    .PARAMETER Credential
        Credential attributes (if required) to test the status of the role or feature.
        Optional.

    .PARAMETER LogPath
        The path to the log file to log this operation.
        Not used in Test-TargetResource.

#>
function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [ValidateSet('Present', 'Absent')]
        [String]
        $Ensure = 'Present',

        [Boolean]
        $IncludeAllSubFeature = $false,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [ValidateNotNullOrEmpty()]
        [String]
        $LogPath

    )

        Write-Verbose -Message ($script:localizedData.TestTargetResourceStartMessage -f ${Name})

        Assert-PrerequisitesValid

        $testTargetResourceResult = $false

        $parameters = $psboundparameters.Remove('Ensure')
        $parameters = $psboundparameters.Remove('IncludeAllSubFeature')

        Write-Verbose -Message ($script:localizedData.QueryFeature -f ${Name})

        $isR2Sp1 = Test-IsWinServer2008R2SP1
        if ($isR2Sp1 -and $psboundparameters.ContainsKey('Credential'))
        {
            $parameters = $psboundparameters.Remove('Credential')
            $feature = Invoke-Command -ScriptBlock { Get-WindowsFeature @using:psboundparameters } `
                                      -ComputerName . `
                                      -Credential $Credential `
                                      -ErrorVariable ev
            $psboundparameters.Add('Credential', $Credential)
        }
        else
        {
            $feature = Get-WindowsFeature @psboundparameters -ErrorVariable ev
        }


        if ($null -eq $ev -or $ev.Count -eq 0)
        {
            Assert-FeatureValid $feature $Name


            # Check if the feature is in the requested Ensure state.
            if (($Ensure -eq 'Present' -and $feature.Installed -eq $true) -or `
                ($Ensure -eq 'Absent' -and $feature.Installed -eq $false))
            {
                $testTargetResourceResult = $true

                if ($IncludeAllSubFeature)
                {
                    # Check if each subfeature is in the requested state.
                    foreach ($currentSubFeature in $feature.SubFeatures)
                    {
                        $parameters = $psboundparameters.Remove('Name')
                        $parameters = $psboundparameters.Remove('Ensure')
                        $parameters = $psboundparameters.Remove('IncludeAllSubFeature')
                        $psboundparameters.Add('Name', $currentSubFeature)

                        $isR2Sp1 = Test-IsWinServer2008R2SP1
                        if ($isR2Sp1 -and $psboundparameters.ContainsKey('Credential'))
                        {
                            $parameters = $psboundparameters.Remove('Credential')
                            $subFeature = Invoke-Command -ScriptBlock { Get-WindowsFeature @using:psboundparameters } -ComputerName . -Credential $Credential -ErrorVariable errorVar
                            $psboundparameters.Add('Credential', $Credential)
                        }
                        else
                        {
                            $subFeature = Get-WindowsFeature @psboundparameters -ErrorVariable errorVar
                        }


                        if ($null -eq $errorVar -or $errorVar.Count -eq 0)
                        {
                            Assert-FeatureValid $subFeature $currentSubFeature

                            if (-not $subFeature.Installed -and $Ensure -eq 'Present')
                            {
                                $testTargetResourceResult = $false
                                break
                            }

                            if ($subFeature.Installed -and $Ensure -eq 'Absent')
                            {
                                $testTargetResourceResult = $false
                                break
                            }
                        }
                    }
                }
            }

            Write-Verbose -Message ($script:localizedData.TestTargetResourceEndMessage -f ${Name})

            return $testTargetResourceResult
        }
}


<#
    .SYNOPSIS
        Asserts that the given feature exists and that there are not multiple instances of it.
        Throws an invalid operation exception if either of the above errors is found.

    .PARAMETER Feature
        The feature object to check for validity.

    .PARAMETER Name
        The name of the feature to include in any error messages that are thrown.
        (Not used to assert validity of the feature).
        
#>
function Assert-FeatureValid
{
    param
    (
        [PSObject]
        $Feature,

        [String]
        $Name
    )

    if ($null -eq $Feature)
    {
        $errorId = 'FeatureNotFound'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($script:localizedData.FeatureNotFoundError) -f ${Name}
        $exception = New-Object System.InvalidOperationException $errorMessage
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        New-InvalidOperationException -Message $errorMessage -ErrorRecord $errorRecord
    }

    if ($Feature.Count -gt 1)
    {
        $errorId = 'FeatureDiscoveryFailure'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidResult
        $errorMessage = $($script:localizedData.FeatureDiscoveryFailureError) -f ${Name}
        $exception = New-Object System.InvalidOperationException $errorMessage
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        New-InvalidOperationException -Message $errorMessage -ErrorRecord $errorRecord
    }
}

<#
    .SYNOPSIS
        Asserts that the MSFT_RoleResource is supported on the target machine.
        MSFT_RoleResource depends on the ServerManager Module
        which is only supported on Server SKU's.
        If ServerManager is not available on the target machine then an Invalid Operation exception
        is thrown.
#>
function Assert-PrerequisitesValid
{
    param 
    ()

    # Enable ServerManager-PSH-Cmdlets feature if OS is WS2008R2 Core.
    $datacenterServerCore = 12
    $standardServerCore = 13
    $EnterpriseServerCore = 14

    $operatingSystem = Get-CimInstance -Class 'Win32_OperatingSystem'
    if ($operatingSystem.Version.StartsWith('6.1.') -and `
        (($operatingSystem.OperatingSystemSKU -eq $datacenterServerCore) -or `
         ($operatingSystem.OperatingSystemSKU -eq $standardServerCore) -or `
         ($operatingSystem.OperatingSystemSKU -eq $EnterpriseServerCore)))
    {
        Write-Verbose -Message $script:localizedData.EnableServerManagerPSHCmdletsFeature

        # Update:ServerManager-PSH-Cmdlets has a depndency on Powershell 2 update: MicrosoftWindowsPowerShell
        # Hence enabling MicrosoftWindowsPowerShell.
        $null = dism /online /enable-feature /FeatureName:MicrosoftWindowsPowerShell
        $null = dism /online /enable-feature /FeatureName:ServerManager-PSH-Cmdlets
    }

    try
    {
        Import-Module -Name 'ServerManager'
    }
    catch
    {
        Write-Verbose -Message $script:localizedData.ServerManagerModuleNotFoundMessage

        $errorId = 'SkuNotSupported'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($script:localizedData.SkuNotSupported)
        $exception = New-Object System.InvalidOperationException $errorMessage
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        New-InvalidOperationException -Message $errorMessage -ErrorRecord $errorRecord
    }
}

<#
    .SYNOPSIS
        Tests if the machine is a Windows Server 2008 R2 SP1 machine.
        Returns $true if so, $false otherwise.
    
    .NOTES
        Since Assert-PrequisitesValid ensures that ServerManager is available on the machine,
        the version is the only thing that needs to be checked in this function.
#>
function Test-IsWinServer2008R2SP1
{
    param
    ()

    if ([Environment]::OSVersion.Version.ToString().Contains('6.1.'))
    {
        return $true
    }

    return $false
}

Export-ModuleMember -Function *-TargetResource
