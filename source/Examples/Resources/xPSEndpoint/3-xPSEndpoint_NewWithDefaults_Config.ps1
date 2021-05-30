<#PSScriptInfo
.VERSION 1.0.1
.GUID be206016-df05-4f2d-8e5a-9bf9416ac33d
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
        Configuration that creates and registers a new session configuration
        endpoint.

    .PARAMETER Name
        The name of the session configuration.

    .EXAMPLE
        xPSEndpoint_NewWithDefaults_Config -Name 'MaintenanceShell'

        Compiles a configuration that creates and registers a new session
        configuration endpoint named 'MaintenanceShell'.
#>
Configuration xPSEndpoint_NewWithDefaults_Config
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xPSEndpoint NewEndpoint
        {
            Name   = $Name
            Ensure = 'Present'
        }
    }
}
