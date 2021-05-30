<#PSScriptInfo
.VERSION 1.0.1
.GUID 5d501d8e-4c4d-472f-ae46-7ef3962f1712
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
        Configuration that removes a registry value.

    .PARAMETER Path
        The path to the key in the registry from which the value should be removed.

    .PARAMETER ValueName
        The name of the value to remove.

    .EXAMPLE
        xRegistryResource_RemoveValueConfig -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -ValueName 'MyValue'

        Compiles a configuration that removes the registry value MyValue from
        the key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'.
#>
Configuration xRegistryResource_RemoveValue_Config
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ValueName
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xRegistry RemoveValue
        {
            Key       = $Path
            Ensure    = 'Absent'
            ValueName = $ValueName
        }
    }
}
