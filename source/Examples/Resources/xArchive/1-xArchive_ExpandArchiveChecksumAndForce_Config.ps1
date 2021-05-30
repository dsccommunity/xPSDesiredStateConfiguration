<#PSScriptInfo
.VERSION 1.0.1
.GUID 2e89ea6a-3911-4305-837e-73f2bf331b87
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
        Configuration that expands the archive using SHA-256 file validation
        located at 'C:\ExampleArchivePath\Archive.zip' to the destination path
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
Configuration xArchive_ExpandArchiveChecksumAndForce_Config
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xArchive Archive1
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
