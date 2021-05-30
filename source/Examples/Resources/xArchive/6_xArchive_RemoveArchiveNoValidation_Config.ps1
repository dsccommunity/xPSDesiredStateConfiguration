<#PSScriptInfo
.VERSION 1.0.1
.GUID 550a8fae-2a63-49b9-aec2-e31e6fd82135
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
        This configuration removes an archive without file validation located at
        'C:\ExampleArchivePath\Archive.zip' from the destination path
        'C:\ExampleDestinationPath\Destination'.

        The resource will only check if the expanded archive files exist at the
        destination.
        No validation is performed on any existing files at the destination to
        ensure that they match the files in the archive before removing them.
#>
Configuration xArchive_RemoveArchiveNoValidation_Config
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xArchive Archive6
        {
            Path        = 'C:\ExampleArchivePath\Archive.zip'
            Destination = 'C:\ExampleDestinationPath\Destination'
            Ensure      = 'Absent'
        }
    }
}
