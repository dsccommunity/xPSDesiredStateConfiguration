<#PSScriptInfo
.VERSION 1.0.1
.GUID 550a8fae-2a63-49b9-aec2-e31e6fd82135
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
        Configuration that removes an archive without file validation.

    .DESCRIPTION
        Removes the expansion of the archive located at
        'C:\ExampleArchivePath\Archive.zip' from the destination path
        'C:\ExampleDestinationPath\Destination'.

        The resource will only check if the expanded archive files exist at the
        destination.
        No validation is performed on any existing files at the destination to
        ensure that they match the files in the archive before removing them.
#>
Configuration xArchive_RemoveArchiveNoValidationConfig
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xArchive Archive5
        {
            Path        = 'C:\ExampleArchivePath\Archive.zip'
            Destination = 'C:\ExampleDestinationPath\Destination'
            Ensure      = 'Absent'
        }
    }
}
