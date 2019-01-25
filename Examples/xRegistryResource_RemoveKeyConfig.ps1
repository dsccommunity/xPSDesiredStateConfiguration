<#PSScriptInfo
.VERSION 1.0.1
.GUID b5662461-5244-4ff7-ae79-df0a79eb3eb0
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
        Configuration that removes a registry key.

    .DESCRIPTION
        Configuration that removes a registry key.

    .PARAMETER Path
        The path to the key in the registry that should be removed.

    .EXAMPLE
        xRegistryResource_AddKeyConfig -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\MyNewKey'

        Compiles a configuration that removes the registry key called MyNewKey under
        the parent key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'.
#>
Configuration xRegistryResource_RemoveKeyConfig
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
        xRegistry 'RemoveKey'
        {
            Key       = $Path
            Ensure    = 'Absent'
            ValueName = ''
        }
    }
}
