<#PSScriptInfo
.VERSION 1.0.1
.GUID 116f2886-58c5-4355-b41a-c57e9a279991
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
        Configuration that creates a new registry key.

    .DESCRIPTION
        Configuration that creates a new registry key called MyNewKey as a sub-key under
        the key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'.

    .PARAMETER Path
        The path to the key in the registry that should be created.

    .EXAMPLE
        xRegistryResource_AddKeyConfig -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\MyNewKey'

        Compiles a configuration that creates a new registry key called MyNewKey under
        the parent key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'.
#>
Configuration xRegistryResource_AddKeyConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xRegistry 'AddKey'
        {
            Key       = $Path
            Ensure    = 'Present'
            ValueName = ''
        }
    }
}
