<#PSScriptInfo
.VERSION 1.0.1
.GUID a9c46276-7e1e-431d-a95b-84282ab171db
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
    .SYNOPSIS
        Sets the Secure Socket Tunneling Protocol and DHCP Client services to
        run under the built-in account LocalService.

    .DESCRIPTION
        Sets the Secure Socket Tunneling Protocol and DHCP Client services to
        run under the built-in account LocalService.

        The current state of the services are ignored.

    .EXAMPLE
        xServiceSet_EnsureBuiltInAccount_Config

        Compiles a configuration that sets the Secure Socket Tunneling Protocol
        and DHCP Client services to run under the built-in account LocalService.
#>
Configuration xServiceSet_EnsureBuiltInAccount_Config
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xServiceSet EnsureBuiltInAccount
        {
            Name           = @('SstpSvc', 'Dhcp')
            Ensure         = 'Present'
            BuiltInAccount = 'LocalService'
            State          = 'Ignore'
        }
    }
}
