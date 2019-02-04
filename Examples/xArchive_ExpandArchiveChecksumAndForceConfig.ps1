<#PSScriptInfo
.VERSION 1.0.1
.GUID 2e89ea6a-3911-4305-837e-73f2bf331b87
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
        Configuration that expands a archive using SHA-256 file validation and
        allows overwriting the folders and files in the destination folder.

    .DESCRIPTION
        Configuration that expands the archive located at
        'C:\ExampleArchivePath\Archive.zip' to the destination path
        'C:\ExampleDestinationPath\Destination'.

        Since Validate is specified as $true and the Checksum parameter is
        specified as SHA-256, the resource will check if the SHA-256 hash of the
        file in the archive matches the SHA-256 hash of the corresponding file
        at the destination and replace any files that do not match.

        Since Force is specified as $true, the resource will overwrite any
        mismatching files at the destination. If Force is specified as $false,
        the resource will throw an error instead of overwrite any files at the
        destination.
#>
Configuration xArchive_ExpandArchiveChecksumAndForceConfig
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xArchive Archive4
        {
            Path        = 'C:\ExampleArchivePath\Archive.zip'
            Destination = 'C:\ExampleDestinationPath\Destination'
            Validate    = $true
            Checksum    = 'SHA-256'
            Force       = $true
            Ensure      = 'Present'
        }
    }
}
