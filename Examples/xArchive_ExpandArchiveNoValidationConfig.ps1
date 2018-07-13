<#PSScriptInfo
.VERSION 1.0.1
.GUID 635a3105-b4bc-482c-a5f2-ebe7127fd671
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
        Configuration that expands a archive without file validation.

    .DESCRIPTION
        Expands the archive located at 'C:\ExampleArchivePath\Archive.zip' to
        the destination path 'C:\ExampleDestinationPath\Destination'.

        The resource will only check if the expanded archive files exist at the
        destination. No validation is performed on any existing files at the
        destination to ensure that they match the files in the archive.
#>
Configuration xArchive_ExpandArchiveNoValidationConfig
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xArchive Archive1
        {
            Path        = 'C:\ExampleArchivePath\Archive.zip'
            Destination = 'C:\ExampleDestinationPath\Destination'
            Ensure      = 'Present'
        }
    }
}
