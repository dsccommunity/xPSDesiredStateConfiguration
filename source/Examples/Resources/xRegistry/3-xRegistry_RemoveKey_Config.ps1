<#PSScriptInfo
.VERSION 1.0.1
.GUID b5662461-5244-4ff7-ae79-df0a79eb3eb0
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
        Configuration that removes a registry key.

    .PARAMETER Path
        The path to the key in the registry that should be removed.

    .EXAMPLE
        xRegistry_AddKey_Config -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\MyNewKey'

        Compiles a configuration that removes the registry key called MyNewKey under
        the parent key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'.
#>
Configuration xRegistry_RemoveKey_Config
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xRegistry RemoveKey
        {
            Key       = $Path
            Ensure    = 'Absent'
            ValueName = ''
        }
    }
}
