<#PSScriptInfo
.VERSION 1.0.1
.GUID 725562ba-fa61-4976-be99-0cf3f04ffc6e
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
        Configuration that adds a role or feature, using the given credentials.

    .DESCRIPTION
        Configuration that adds a role or feature, using the given credentials.

    .PARAMETER Name
        Name of the role or feature that you want to ensure is added.
        This is the same as the Name parameter from the Get-WindowsFeature
        cmdlet, and not the display name of the role or feature.

    .PARAMETER Credential
        The credentials to use to add or remove the role or feature.

    .PARAMETER IncludeAllSubFeature
        Set this parameter to $true to ensure the state of all required
        sub-features with the state of the feature you specify with the Name
        parameter. The default value is $false.

    .EXAMPLE
        xWindowsFeature_AddFeatureUsingCredentialConfig -Name 'Telnet-Client' -IncludeAllSubFeature $false -Credential (Get-Credential)

        Compiles a configuration that adds the feature Telnet-Client.
#>
Configuration xWindowsFeature_AddFeatureUsingCredentialConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.Boolean]
        $IncludeAllSubFeature,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xWindowsFeature 'AddFeatureUsingCredential'
        {
            Name                 = $Name
            Ensure               = 'Present'
            IncludeAllSubFeature = $IncludeAllSubFeature
            Credential           = $Credential
        }
    }
}
