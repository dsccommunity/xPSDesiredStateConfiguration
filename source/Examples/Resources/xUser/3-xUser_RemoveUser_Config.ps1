<#PSScriptInfo
.VERSION 1.0.1
.GUID 87c4e4fa-7519-4838-b187-b6a2ff8d1a45
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
        Configuration that removes a local user account using the given username.

    .PARAMETER UserName
        The username of the local user account to remove.

    .EXAMPLE
        xUser_RemoveUser_Config -UserName 'MyUser'

        Compiles a configuration that removes a local user account.
#>
Configuration xUser_RemoveUser_Config
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $UserName
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xUser RemoveUserAccount
        {
            Ensure   = 'Absent'
            UserName = $UserName
        }
    }
}
