<#PSScriptInfo
.VERSION 1.0.1
.GUID 36eb8f8c-e34c-4ec5-be10-8936b415a9a1
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
        Configuration that expands a archive under a credential without file
        validation.

    .DESCRIPTION
        Expands the archive located at 'C:\ExampleArchivePath\Archive.zip' to
        the destination path 'C:\ExampleDestinationPath\Destination'.

        The added specification of a Credential here allows you to provide the
        credential of a user to provide the resource access to the archive and
        destination paths.

        The resource will only check if the expanded archive files exist at the
        destination. No validation is performed on any existing files at the
        destination to ensure that they match the files in the archive.
#>
Configuration xArchive_ExpandArchiveNoValidationCredentialConfig
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xArchive Archive2
        {
            Path        = 'C:\ExampleArchivePath\Archive.zip'
            Destination = 'C:\ExampleDestinationPath\Destination'
            Credential  = $Credential
            Ensure      = 'Present'
        }
    }
}
