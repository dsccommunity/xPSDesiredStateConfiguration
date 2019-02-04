<#PSScriptInfo
.VERSION 1.0.1
.GUID 281e1f4d-d196-4d0c-9444-bc40ec6ff9de
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
        Configuration that removes a role or feature.

    .DESCRIPTION
        Configuration that removes a role or feature.

    .PARAMETER Name
        Name of the role or feature that you want to ensure is removed.
        This is the same as the Name parameter from the Get-WindowsFeature
        cmdlet, and not the display name of the role or feature.

    .PARAMETER IncludeAllSubFeature
        Set this parameter to $true to ensure the state of all required
        sub-features with the state of the feature you specify with the Name
        parameter. The default value is $false.

    .EXAMPLE
        xWindowsFeature_RemoveFeatureConfig -Name 'Telnet-Client' -IncludeAllSubFeature $false

        Compiles a configuration that adds the feature Telnet-Client.
#>
Configuration xWindowsFeature_RemoveFeatureConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.Boolean]
        $IncludeAllSubFeature
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xWindowsFeature 'RemoveFeature'
        {
            Name                 = $Name
            Ensure               = 'Absent'
            IncludeAllSubFeature = $IncludeAllSubFeature
        }
    }
}

