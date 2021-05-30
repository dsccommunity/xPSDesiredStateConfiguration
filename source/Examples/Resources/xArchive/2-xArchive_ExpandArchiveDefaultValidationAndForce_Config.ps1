<#PSScriptInfo
.VERSION 1.0.1
.GUID f064901d-086a-410c-8b2a-d0e471b8eddb
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
        Expands the archive using default file validation located at
        'C:\ExampleArchivePath\Archive.zip' to the destination path
        'C:\ExampleDestinationPath\Destination'.

        Since Validate is specified as $true and the Checksum parameter is not
        provided, the resource will check if the last write time of the archive
        file matches the last write time of the corresponding file at the
        destination and replace any files that do not match.

        Since Force is specified as $true, the resource will overwrite any
        mismatching files at the destination. If Force is specified as $false,
        the resource will throw an error instead of overwrite any files at the
        destination.
#>
Configuration xArchive_ExpandArchiveDefaultValidationAndForce_Config
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xArchive Archive2
        {
            Path        = 'C:\ExampleArchivePath\Archive.zip'
            Destination = 'C:\ExampleDestinationPath\Destination'
            Validate    = $true
            Force       = $true
            Ensure      = 'Present'
        }
    }
}
