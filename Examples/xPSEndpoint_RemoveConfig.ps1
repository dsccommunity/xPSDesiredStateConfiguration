<#PSScriptInfo
.VERSION 1.0.1
.GUID 6a28a133-9d81-451b-a07f-eb9c61b4d283
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
        Configuration that removes an existing session configuration endpoint.

    .DESCRIPTION
        Configuration that creates and registers a new session configuration
        endpoint.

    .PARAMETER Name
        The name of the session configuration.

    .EXAMPLE
        xPSEndpoint_RemoveConfig -Name 'MaintenanceShell'

        Compiles a configuration that removes the session configuration
        endpoint named 'MaintenanceShell'.
#>
configuration xPSEndpoint_RemoveConfig
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
        xPSEndpoint 'RemoveEndpoint'
        {
            Name       = $Name
            Ensure     = 'Absent'
        }
    }
}
