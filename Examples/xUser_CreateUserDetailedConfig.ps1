<#PSScriptInfo
.VERSION 1.0.1
.GUID 3353a4c7-e6b0-4ca9-852d-86d0c4a3e9a5
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

    .PARAMETER FullName
        Full name of the local user account. Defaults to the name passed in the credentials.

    .PARAMETER Description
        Description of the local user account. Defaults to no description.

    .PARAMETER PasswordNeverExpires
        To ensure that the password for this account will never expire, set this
        property to $true, and set it to $false if the password will expire.
        Defaults to $false.

    .PARAMETER PasswordChangeRequired
        If the user must change the password at the next sign in. Set this
        property to $true if the user must change the password. Defaults to
        $false.

    .PARAMETER PasswordChangeNotAllowed
        If the user can change the password. Set this property to $true to ensure
        that the user cannot change the password, and set it to $false to allow
        the user to change the password. Defaults to $false.

    .PARAMETER Disabled
        If the account is enabled. Set this property to $true to ensure that
        this account is disabled, and set it to $false to ensure that it is
        enabled. Defaults to $false.

    .NOTES
        If you want to create a user with minimal attributes, every parameter,
        except username and password, can be deleted since they are optional.

        If the parameters are present then they will be evaluated to be in
        desired state, meaning if for example Description parameter is left as
        the default value, then the desired state is to have no description on
        the local user account.

    .EXAMPLE
        xUser_CreateUserDetailedConfig -Credential = (Get-Credential) -FullName = 'MyUser' -Description = 'My local user account' -PasswordNeverExpires = $true -PasswordChangeRequired = $false -PasswordChangeNotAllowed = $false -Disabled = $false

        Compiles a configuration that creates a local user account.
#>
Configuration xUser_CreateUserDetailedConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter()]
        [System.String]
        $FullName,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.Boolean]
        $PasswordNeverExpires,

        [Parameter()]
        [System.Boolean]
        $PasswordChangeRequired,

        [Parameter()]
        [System.Boolean]
        $PasswordChangeNotAllowed,

        [Parameter()]
        [System.Boolean]
        $Disabled
    )

    Import-DSCResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        if (-not $FullName)
        {
            $FullName = $Credential.UserName
        }

        xUser 'CreateUserAccount'
        {
            Ensure                   = 'Present'
            UserName                 = Split-Path -Path $Credential.UserName -Leaf
            Password                 = $Credential
            FullName                 = $FullName
            Description              = $Description
            PasswordNeverExpires     = $PasswordNeverExpires
            PasswordChangeRequired   = $PasswordChangeRequired
            PasswordChangeNotAllowed = $PasswordChangeNotAllowed
            Disabled                 = $Disabled
        }
    }
}
