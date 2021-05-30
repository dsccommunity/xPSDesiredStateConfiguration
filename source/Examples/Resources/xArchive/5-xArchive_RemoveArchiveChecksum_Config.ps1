<#PSScriptInfo
.VERSION 1.0.1
.GUID 662aee36-85dd-47fc-88e8-73d7b4e5f822
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
        This configuration removes an archive with SHA-256 file validation located at
        'C:\ExampleArchivePath\Archive.zip' from the destination path
        'C:\ExampleDestinationPath\Destination'.

        Since Validate is specified as $true and the Checksum parameter is
        specified as SHA-256, the resource will check if the SHA-256 hash of the
        file in the archive matches the SHA-256 hash of the corresponding file
        at the destination and will not remove any files that do not match.
#>
Configuration xArchive_RemoveArchiveChecksum_Config
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xArchive Archive5
        {
            Path        = 'C:\ExampleArchivePath\Archive.zip'
            Destination = 'C:\ExampleDestinationPath\Destination'
            Validate    = $true
            Checksum    = 'SHA-256'
            Ensure      = 'Absent'
        }
    }
}
