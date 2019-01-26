<#PSScriptInfo
.VERSION 1.0.1
.GUID ea0e3b37-9a9e-4331-8dc6-f95ff353b3d4
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/PowerShell/xPSDesiredStateConfiguration/blob/master/LICENSE
.PROJECTURI https://github.com/PowerShell/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -module @{ModuleName = 'xPSDesiredStateConfiguration';ModuleVersion = '8.2.0.0'}

<#
    .SYNOPSIS
        Configuration that adds a role or feature, and outputs a log to the
        specified file.

    .DESCRIPTION
        Configuration that adds a  role or feature, and outputs a log to the
        specified file.

    .PARAMETER Name
        Name of the role or feature that you want to ensure is added.
        This is the same as the Name parameter from the Get-WindowsFeature
        cmdlet, and not the display name of the role or feature.

    .PARAMETER IncludeAllSubFeature
        Set this parameter to $true to ensure the state of all required
        sub-features with the state of the feature you specify with the Name
        parameter. The default value is $false.

    .PARAMETER LogPath
        The path to a log file to log the operation.

    .EXAMPLE
        xWindowsFeature_AddFeatureWithLogPathConfig -Name 'Telnet-Client' -IncludeAllSubFeature $false -LogPath "$env:TEMP\windowsfeature.log"

        Compiles a configuration that adds the feature Telnet-Client.
#>
Configuration xWindowsFeature_AddFeatureWithLogPathConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $LogPath,

        [Parameter()]
        [System.Boolean]
        $IncludeAllSubFeature
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xWindowsFeature 'AddFeatureWithLogPath'
        {
            Name                 = $Name
            Ensure               = 'Present'
            IncludeAllSubFeature = $IncludeAllSubFeature
            LogPath              = $LogPath
        }
    }
}

