<#PSScriptInfo
.VERSION 1.0.0
.GUID 5d501d8e-4c4d-472f-ae46-7ef3962f1712
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
