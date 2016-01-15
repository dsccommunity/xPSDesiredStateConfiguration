# This PS module contains functions for Desired State Configuration Windows Optional Feature provider. It enables configuring optional features on Windows Client SKUs.

# Fallback message strings in en-US
DATA localizedData
{
    # culture = "en-US"
    ConvertFrom-StringData @'
        DismNotAvailable = PowerShell module Dism could not be imported.
        NotSupportedSku = This Resource is only available for Windows Client or Server 2012 (or later).
        ElevationRequired = This Resource requires to be run as an Administrator.
        ValidatingPrerequisites = Validating prerequisites...
        CouldNotCovertFeatureState = Could not convert feature state '{0}' into Absent/Present.
        EnsureNotSupported = The value '{0}' for property Ensure is not supported.
        RestartNeeded = Target machine needs to be restarted.
        GetTargetResourceStartMessage = Begin executing Get functionality on the {0} feature.
        GetTargetResourceEndMessage = End executing Get functionality on the {0} feature.
        SetTargetResourceStartMessage = Begin executing Set functionality on the {0} feature.
        SetTargetResourceEndMessage = End executing Set functionality on the {0} feature.
        TestTargetResourceStartMessage = Begin executing Test functionality on the {0} feature.
        TestTargetResourceEndMessage = End executing Test functionality on the {0} feature.
        FeatureInstalled = Installed feature {0}.
        FeatureUninstalled = Uninstalled feature {0}.
'@
}
Import-Module Dism -Force -ErrorAction SilentlyContinue

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    Write-Debug ($LocalizedData.GetTargetResourceStartMessage -f $Name)

    ValidatePrerequisites

    $result = Dism\Get-WindowsOptionalFeature -FeatureName $Name -Online

    $returnValue = @{
        LogPath = $result.LogPath
        Ensure = ConvertStateToEnsure $result.State
        CustomProperties = SerializeCustomProperties $result.CustomProperties
        Name = $result.FeatureName
        LogLevel = $result.LogLevel
        Description = $result.Description
        DisplayName = $result.DisplayName
    }

    $returnValue

    Write-Debug ($LocalizedData.GetTargetResourceEndMessage -f $Name)
}

# Serializes a list of CustomProperty objects into [System.String[]]
function SerializeCustomProperties
{
    param
    (
        $CustomProperties
    )

    $CustomProperties | ? {$_ -ne $null} | % { "Name = $($_.Name), Value = $($_.Value), Path = $($_.Path)" }
}

# Converts state returned by Dism Get-WindowsOptionalFeature cmdlet to Present/Absent
function ConvertStateToEnsure
{
    param
    (
        $State
    )

    if ($state -eq 'Disabled')
    {
        'Absent'
    }
    elseif ($state -eq 'Enabled')
    {
        'Present'
    }
    else
    {
        Write-Warning ($LocalizedData.CouldNotCovertFeatureState -f $state)
        $state
    }
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [System.String[]]
        $Source,

        [System.Boolean]
        $RemoveFilesOnDisable,

        [System.String]
        $LogPath,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [System.Boolean]
        $NoWindowsUpdateCheck,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("ErrorsOnly","ErrorsAndWarning","ErrorsAndWarningAndInformation")]
        [System.String]
        $LogLevel
    )

    Write-Debug ($LocalizedData.SetTargetResourceStartMessage -f $Name)

    ValidatePrerequisites

    switch ($LogLevel)
    {
        'ErrorsOnly' { $DismLogLevel = 'Errors' }
        'ErrorsAndWarning' { $DismLogLevel = 'Warnings' }
        'ErrorsAndWarningAndInformation' { $DismLogLevel = 'WarningsInfo' }
        '' { $DismLogLevel = 'WarningsInfo' }
    }

    # construct parameters for Dism cmdlets
    $PSBoundParameters.Remove('Name') > $null
    $PSBoundParameters.Remove('Ensure') > $null
    if ($PSBoundParameters.ContainsKey('RemoveFilesOnDisable'))
    {
        $PSBoundParameters.Remove('RemoveFilesOnDisable')
    }

    if ($PSBoundParameters.ContainsKey('NoWindowsUpdateCheck'))
    {
        $PSBoundParameters.Remove('NoWindowsUpdateCheck')
    }

    if ($PSBoundParameters.ContainsKey('LogLevel'))
    {
        $PSBoundParameters.Remove('LogLevel')
    }

    if ($Ensure -eq 'Present')
    {
        if ($NoWindowsUpdateCheck)
        {
            $feature = Dism\Enable-WindowsOptionalFeature -FeatureName $Name -Online -LogLevel $DismLogLevel @PSBoundParameters -LimitAccess -NoRestart
        }
        else
        {
            $feature = Dism\Enable-WindowsOptionalFeature -FeatureName $Name -Online -LogLevel $DismLogLevel @PSBoundParameters -NoRestart
        }

        Write-Verbose ($LocalizedData.FeatureInstalled -f $Name)
    }
    elseif ($Ensure -eq 'Absent')
    {
        if ($RemoveFilesOnDisable)
        {
            $feature = Dism\Disable-WindowsOptionalFeature -FeatureName $Name -Online -LogLevel $DismLogLevel @PSBoundParameters -Remove -NoRestart
        }
        else
        {
            $feature = Dism\Disable-WindowsOptionalFeature -FeatureName $Name -Online -LogLevel $DismLogLevel @PSBoundParameters -NoRestart
        }

        Write-Verbose ($LocalizedData.FeatureUninstalled -f $Name)
    }
    else
    {
        throw ($LocalizedData.EnsureNotSupported -f $Ensure)
    }

    ## Indicate we need a restart as needed
    if ($feature.RestartNeeded)
    {
        Write-Verbose $LocalizedData.RestartNeeded
        $global:DSCMachineStatus = 1
    }

    Write-Debug ($LocalizedData.SetTargetResourceEndMessage -f $Name)
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [System.String[]]
        $Source,

        [System.Boolean]
        $RemoveFilesOnDisable,

        [System.String]
        $LogPath,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [System.Boolean]
        $NoWindowsUpdateCheck,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("ErrorsOnly","ErrorsAndWarning","ErrorsAndWarningAndInformation")]
        [System.String]
        $LogLevel
    )

    Write-Debug ($LocalizedData.TestTargetResourceStartMessage -f $Name)

    ValidatePrerequisites

    $featureState = Dism\Get-WindowsOptionalFeature -FeatureName $Name -Online
    [bool] $result = $false

    if ($featureState -eq $null)
    {
        $result = $Ensure -eq 'Absent'
    }
    if (($featureState.State -eq 'Disabled' -and $Ensure -eq 'Absent')`
        -or ($featureState.State -eq 'Enabled' -and $Ensure -eq 'Present'))
    {
        $result = $true
    }
    Write-Debug ($LocalizedData.TestTargetResourceEndMessage -f $Name)
    return $result
}


# ValidatePrerequisites is a helper function used to validate if the MSFT_WindowsOptionalFeature is supported on the target machine.
function ValidatePrerequisites
{
    Write-Verbose $LocalizedData.ValidatingPrerequisites

    # check that we're running on Server 2012 (or later) or on a client SKU
    $os = Get-CimInstance -ClassName Win32_OperatingSystem

    if (($os.ProductType -ne 1) -and ([System.Int32] $os.BuildNumber -lt 9600))
    {
        throw $LocalizedData.NotSupportedSku
    }

    # check that we are running elevated
    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($windowsIdentity)
    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

    if (!$windowsPrincipal.IsInRole($adminRole))
    {
        throw $LocalizedData.ElevationRequired
    }

    # check that Dism PowerShell module is available
    Import-Module Dism -Force -ErrorVariable ev -ErrorAction SilentlyContinue

    if ($ev.Count -gt 0)
    {
        throw $LocalizedData.DismNotAvailable
    }
}


Export-ModuleMember -Function *-TargetResource



