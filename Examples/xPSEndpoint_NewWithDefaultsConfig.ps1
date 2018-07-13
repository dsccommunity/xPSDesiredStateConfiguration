<#PSScriptInfo
.VERSION 1.0.1
.GUID be206016-df05-4f2d-8e5a-9bf9416ac33d
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
        Configuration that creates and registers a new session configuration
        endpoint.

    .DESCRIPTION
        Configuration that creates and registers a new session configuration
        endpoint.

    .PARAMETER Name
        The name of the session configuration.

    .EXAMPLE
        xPSEndpoint_NewWithDefaultsConfig -Name 'MaintenanceShell'

        Compiles a configuration that creates and registers a new session
        configuration endpoint named 'MaintenanceShell'.
#>
configuration xPSEndpoint_NewWithDefaultsConfig
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node 'localhost'
    {
        xPSEndpoint 'NewEndpoint'
        {
            Name   = $Name
            Ensure = 'Present'
        }
    }
}
