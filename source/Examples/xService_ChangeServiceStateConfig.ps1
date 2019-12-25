<#PSScriptInfo
.VERSION 1.0.1
.GUID 7e8e91ba-ab33-4d7a-8b17-6fca60ccd040
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
        Configuration that changes the state for an existing service.

    .DESCRIPTION
        Configuration that changes the state for an existing service.

    .PARAMETER Name
        The name of the Windows service.

    .PARAMETER State
        The state that the Windows service should have.

    .EXAMPLE
        xService_ChangeServiceStateConfig -Name 'spooler' -State 'Stopped'

        Compiles a configuration that make sure the state for the Windows
        service 'spooler' is 'Stopped'. If the service is running the
        Windows service will be stopped.
#>
Configuration xService_ChangeServiceStateConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('Running', 'Stopped')]
        [System.String]
        $State = 'Running'
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xService 'ChangeServiceState'
        {
            Name   = $Name
            State  = $State
            Ensure = 'Present'
        }
    }
}
