<#PSScriptInfo
.VERSION 1.0.1
.GUID 6e48f4f6-5b67-4868-ba72-9732dc40ee98
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
        Configuration that stops and then removes a Windows service.

    .DESCRIPTION
        Configuration that stops and then removes a Windows service.

    .PARAMETER Name
        The name of the Windows service to be removed.

    .EXAMPLE
        xService_RemoveServiceConfig  -Name 'Service1'

        Compiles a configuration that stops and then removes the service with the
        name Service1.
#>
Configuration xService_RemoveServiceConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xService 'RemoveService'
        {
            Name   = $Name
            Ensure = 'Absent'
        }
    }
}
