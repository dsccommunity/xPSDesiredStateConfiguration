<#PSScriptInfo
.VERSION 1.0.1
.GUID 2becfdf4-6679-47bb-9755-7ed2075607d6
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/xPSDesiredStateConfiguration/blob/main/LICENSE
.PROJECTURI https://github.com/dsccommunity/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -Module xPSDesiredStateConfiguration

<#
    .DESCRIPTION
        Configuration that adds a role or feature.

    .PARAMETER Name
        Name of the role or feature that you want to ensure is added.
        This is the same as the Name parameter from the Get-WindowsFeature
        cmdlet, and not the display name of the role or feature.

    .PARAMETER IncludeAllSubFeature
        Set this parameter to $true to ensure the state of all required
        sub-features with the state of the feature you specify with the Name
        parameter. The default value is $false.

    .EXAMPLE
        xWindowsFeature_AddFeature_Config -Name 'Telnet-Client' -IncludeAllSubFeature $false

        Compiles a configuration that adds the feature Telnet-Client.
#>
Configuration xWindowsFeature_AddFeature_Config
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

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xWindowsFeature AddFeature
        {
            Name                 = $Name
            Ensure               = 'Present'
            IncludeAllSubFeature = $IncludeAllSubFeature
        }
    }
}

