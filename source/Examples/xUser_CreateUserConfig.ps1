<#PSScriptInfo
.VERSION 1.0.1
.GUID e694ded5-b732-4537-9df2-456f2374264e
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
        Configuration that creates a local user account using the given credentials.

    .DESCRIPTION
        Configuration that creates a local user account using the given credentials.

    .PARAMETER Credential
        Credentials to use to create the local user account.

    .EXAMPLE
        xUser_CreateUserConfig -Credential (Get-Credential)

        Compiles a configuration that creates a local user account.
#>
Configuration xUser_CreateUserConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Import-DSCResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xUser 'CreateUserAccount'
        {
            Ensure   = 'Present'
            UserName = Split-Path -Path $Credential.UserName -Leaf
            Password = $Credential
        }
    }
}
