
Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonResourceHelper.psm1')

# Localized messages for Write-Verbose statements in this resource
$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_xWindowsFeature'

# The Get-TargetResource cmdlet is used to fetch the status of role or feature on the target machine.
# It gives the feature info of the requested role/feature on the target machine.

# If a feature does not contain any SubFeatures then $includeAllSubFeature would be set to $false.
# If a feature contains one or more subfeatures then $includeAllSubFeature would be set to
# $true only if all the subfeatures are installed, or else $includeAllSubFeature would be set to $false.
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

        $getTargetResourceStartVerboseMessage = $($script:localizedData.GetTargetResourceStartVerboseMessage) -f ${Name} 
        Write-Verbose -Message $getTargetResourceStartVerboseMessage

        Assert-PrerequisitesValid 

        $queryFeatureMessage = $($script:localizedData.QueryFeature) -f ${Name} 
        Write-Verbose -Message $queryFeatureMessage

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

                $getTargetResourceEndVerboseMessage = $($script:localizedData.GetTargetResourceEndVerboseMessage) -f ${Name} 
                Write-Verbose -Message $getTargetResourceEndVerboseMessage

                $getTargetResourceResult
            }
        }
}


# The Set-TargetResource cmdlet is used to install or uninstall a role on the target machine.
# It also supports installing & uninstalling the role or feature specific subfeatures.
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

       [ValidateNotNullOrEmpty()]
       [String]
       $Source,

       [Boolean]
       $IncludeAllSubFeature = $false,

       [System.Management.Automation.PSCredential]
       [System.Management.Automation.Credential()]
       $Credential,

       [ValidateNotNullOrEmpty()]
       [String]
       $LogPath
    )

    $setTargetResourceStartVerboseMessage = $($script:localizedData.SetTargetResourceStartVerboseMessage) -f ${Name} 
    Write-Verbose -Message $setTargetResourceStartVerboseMessage

    Assert-PrerequisitesValid 

    # -Source Parameter is not applicable to Windows Server 2008 R2 SP1. Hence removing it.
    # all role/feature spcific binaries are avaliable inboc on Windows Server 2008 R2 SP1, hence
    # -Source is not supported on Windows Server 2008 R2 SP1.
    $isR2Sp1 = Test-IsWinServer2008R2SP1
    if ($isR2Sp1 -and $psboundparameters.ContainsKey('Source'))
    {
        $sourcePropertyNotSupportedDebugMessage = $($script:localizedData.SourcePropertyNotSupportedDebugMessage) 
        Write-Verbose -Message $sourcePropertyNotSupportedDebugMessage

        $parameters = $psboundparameters.Remove('Source')
    }


    if ($Ensure -eq 'Present')
    {
        $parameters = $psboundparameters.Remove('Ensure')

        $installFeatureMessage = $($script:localizedData.InstallFeature) -f ${Name} 
        Write-Verbose -Message $installFeatureMessage

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
                $restartNeededMessage = $($script:localizedData.RestartNeeded)
                Write-Verbose -Message $restartNeededMessage

                $global:DSCMachineStatus = 1
            }
        }
        else
        {
            # Add-WindowsFeature cmdlet falied to successfully install the requested feature.
            # If there are errors from the Add-WindowsFeature cmdlet. We surface those errors.
            # If Add-WindwosFeature cmdlet does not surface any errors. Then the provider throws a
            # terminating error.
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
        $parameters = $psboundparameters.Remove('Source')

        $uninstallFeatureMessage = $($script:localizedData.UninstallFeature) -f ${Name} 
        Write-Verbose -Message $uninstallFeatureMessage

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
                $restartNeededMessage = $($script:localizedData.RestartNeeded)
                Write-Verbose -Message $restartNeededMessage

                $global:DSCMachineStatus = 1
            }
        }
        else
        {
            # Remove-WindowsFeature cmdlet falied to successfully Uninstall the requested feature.
            # If there are errors from the Remove-WindowsFeature cmdlet. We surface those errors.
            # If Remove-WindwosFeature cmdlet does not surface any errors. Then the provider throws a
            # terminating error.
            if ($null -eq $ev -or $ev.Count -eq 0)
            {
                $errorId = 'FeatureUnInstallationFailure'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                $errorMessage = $($script:localizedData.FeatureUnInstallationFailureError) -f ${Name} 
                $exception = New-Object System.InvalidOperationException $errorMessage 
                $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

                New-InvalidOperationException -Message $errorMessage -ErrorRecord $errorRecord
            }
        }
    }

    $setTargetResourceEndVerboseMessage = $($script:localizedData.SetTargetResourceEndVerboseMessage) -f ${Name} 
    Write-Verbose -Message $setTargetResourceEndVerboseMessage
}

# The Test-TargetResource cmdlet is used to validate if the role or feature is in a state as expected in the instance document.
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

        [ValidateNotNullOrEmpty()]
        [String]
        $Source,

        [Boolean]
        $IncludeAllSubFeature = $false,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [ValidateNotNullOrEmpty()]
        [String]
        $LogPath

    )

        $testTargetResourceStartVerboseMessage = $($script:localizedData.TestTargetResourceStartVerboseMessage) -f ${Name} 
        Write-Verbose -Message $testTargetResourceStartVerboseMessage

        Assert-PrerequisitesValid

        # -Source Parameter is not applicable to Windows Server 2008 R2 SP1. Hence removing it.
        # all role/feature spcific binaries are avaliable inboc on Windows Server 2008 R2 SP1, hence
        # -Source is not supported on Windows Server 2008 R2 SP1.
        $isR2Sp1 = Test-IsWinServer2008R2SP1
        if ($isR2Sp1 -and $psboundparameters.ContainsKey('Source'))
        {
            $sourcePropertyNotSupportedDebugMessage = $($script:localizedData.SourcePropertyNotSupportedDebugMessage) 
            Write-Verbose -Message $sourcePropertyNotSupportedDebugMessage

            $parameters = $psboundparameters.Remove('Source')
        }

        $testTargetResourceResult = $false

        $parameters = $psboundparameters.Remove('Ensure')
        $parameters = $psboundparameters.Remove('IncludeAllSubFeature')
        $parameters = $psboundparameters.Remove('Source')

        $queryFeatureMessage = $($script:localizedData.QueryFeature) -f ${Name} 
        Write-Verbose -Message $queryFeatureMessage

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
            # If so then check if then check if the subfeature is in the requested Ensure state.
            if (($Ensure -eq 'Present' -and $feature.Installed -eq $true) -or `
                ($Ensure -eq 'Absent' -and $feature.Installed -eq $false))
            {
                $testTargetResourceResult = $true

                # IncludeAllSubFeature is set to $true, so we need to make
                # sure that all Sub Features are also installed.
                if ($IncludeAllSubFeature)
                {
                    foreach ($currentSubFeature in $feature.SubFeatures)
                    {
                        $parameters = $psboundparameters.Remove('Name')
                        $parameters = $psboundparameters.Remove('Ensure')
                        $parameters = $psboundparameters.Remove('IncludeAllSubFeature')
                        $parameters = $psboundparameters.Remove('Source')
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

            $testTargetResourceEndVerboseMessage = $($script:localizedData.TestTargetResourceEndVerboseMessage) -f ${Name} 
            Write-Verbose -Message $testTargetResourceEndVerboseMessage

            $testTargetResourceResult
        }
}


# Assert-FeatureValid is a helper function used to validate the results of SM+ cmdlets
# Get-Windowsfeature for the user supplied feature name.
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

    # WildCard pattern is not supported by the role provider.
    # Hence we restrict user to request only one feature information in a single request.
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

# Assert-PrerequisitesValid is a helper function used to validate if the MSFT_RoleResource is supported on the target machine.
# MSFT_RoleResource is supported only on Server SKU's. MSFT_RoleResource depends on ServerManagerModule which is avaliable
# only on Server SKU's.
function Assert-PrerequisitesValid
{
    param 
    ()

    #Enable ServerManager-PSH-Cmdlets feature if os is WS2008R2 Core.
    $datacenterServerCore = 12
    $standardServerCore = 13
    $EnterpriseServerCore = 14

    $operatingSystem = Get-WmiObject -Class Win32_operatingsystem
    if ($operatingSystem.Version.StartsWith('6.1.') -and `
        (($operatingSystem.OperatingSystemSKU -eq $datacenterServerCore) -or `
         ($operatingSystem.OperatingSystemSKU -eq $standardServerCore) -or `
         ($operatingSystem.OperatingSystemSKU -eq $EnterpriseServerCore)))
    {
        Write-Verbose -Message $($script:localizedData.EnableServerManagerPSHCmdletsFeature)

        # Update:ServerManager-PSH-Cmdlets has a depndency on Powershell 2 update: MicrosoftWindowsPowerShell
        # Hence enabling MicrosoftWindowsPowerShell.
        dism /online /enable-feature /FeatureName:MicrosoftWindowsPowerShell | Out-Null
        dism /online /enable-feature /FeatureName:ServerManager-PSH-Cmdlets | Out-Null
    }

    try
    {
    
        Import-Module ServerManager -PassThru
    }
    catch
    {

        $serverManagerModuleNotFoundDebugMessage = $($script:localizedData.ServerManagerModuleNotFoundDebugMessage)
        Write-Verbose -Message $serverManagerModuleNotFoundDebugMessage

        $errorId = 'SkuNotSupported'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($script:localizedData.SkuNotSupported)
        $exception = New-Object System.InvalidOperationException $errorMessage
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        New-InvalidOperationException -Message $errorMessage -ErrorRecord $errorRecord
    }
}


# Test-IsWinServer2008R2SP1 is a helper function to detect if the target machine is a Win 2008 R2 SP1.
function Test-IsWinServer2008R2SP1
{
    param
    ()

    # We are already checking for the Presence of ServerManager module before using this helper function.
    # Hence checking for the version shoudl be good enough to confirm that the target machine is
    # Windows Server 2008 R2 machine.
    if ([Environment]::OSVersion.Version.ToString().Contains('6.1.'))
    {
        return $true
    }

    return $false
}

Export-ModuleMember -Function *-TargetResource
