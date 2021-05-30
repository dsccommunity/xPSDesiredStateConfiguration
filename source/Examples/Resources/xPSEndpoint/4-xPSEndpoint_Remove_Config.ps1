<#PSScriptInfo
.VERSION 1.0.1
.GUID 6a28a133-9d81-451b-a07f-eb9c61b4d283
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
        xPSEndpoint_Remove_Config -Name 'MaintenanceShell'

        Compiles a configuration that removes the session configuration
        endpoint named 'MaintenanceShell'.
#>
Configuration xPSEndpoint_Remove_Config
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
        xPSEndpoint RemoveEndpoint
        {
            Name       = $Name
            Ensure     = 'Absent'
        }
    }
}
