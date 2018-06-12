
<#PSScriptInfo
.VERSION 1.0.0
.GUID 5a442bad-d301-463e-9510-79193ff1bf88
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/PowerShell/xPSDesiredStateConfiguration/blob/master/LICENSE
.PROJECTURI https://github.com/PowerShell/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES xPSDesiredStateConfiguration
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -module @{ModuleName = 'xPSDesiredStateConfiguration';ModuleVersion = '8.2.0.0'}

<#
    .DESCRIPTION
        Updates startup type to manual for the service Print Spooler, ignoring
        it's current state (e.g. running, stopped, etc).

    .NOTES
        If the service with the name spooler does not exist, this configuration would throw an
        error since the Path is not included here.

        If the service with the name spooler already exists, sets the startup type of the service
        with the name spooler to Manual and ignores the state that the service is currently in.
        If State is not specified, the configuration will ensure that the state of the service is
        Running by default.
#>
Configuration xService_UpdateStartupTypeIgnoreStateConfig
{
    [CmdletBinding()]
    param ()

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xService ServiceResource1
        {
            Name = 'spooler'
            Ensure = 'Present'
            StartupType = 'Manual'
            State = 'Ignore'
        }
    }
}


