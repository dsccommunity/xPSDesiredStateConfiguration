<#PSScriptInfo
.VERSION 1.0.1
.GUID e694ded5-b732-4537-9df2-456f2374264e
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
        Configuration that creates a local user account using the given credentials.

    .PARAMETER Credential
        Credentials to use to create the local user account.

    .EXAMPLE
        xUser_CreateUser_Config -Credential (Get-Credential)

        Compiles a configuration that creates a local user account.
#>
Configuration xUser_CreateUser_Config
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Import-DSCResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xUser CreateUserAccount
        {
            Ensure   = 'Present'
            UserName = Split-Path -Path $Credential.UserName -Leaf
            Password = $Credential
        }
    }
}
