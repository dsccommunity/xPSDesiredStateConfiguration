<#PSScriptInfo
.VERSION 1.0.1
.GUID 87c4e4fa-7519-4838-b187-b6a2ff8d1a45
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
        Configuration that removes a local user account using the given username.

    .DESCRIPTION
        Configuration that removes a local user account using the given username.

    .PARAMETER UserName
        The username of the local user account to remove.

    .EXAMPLE
        xUser_RemoveUserConfig -UserName 'MyUser'

        Compiles a configuration that removes a local user account.
#>
Configuration xUser_RemoveUserConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $UserName
    )

    Import-DSCResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xUser 'RemoveUserAccount'
        {
            Ensure   = 'Absent'
            UserName = $UserName
        }
    }
}
