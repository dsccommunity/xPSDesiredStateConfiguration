<#PSScriptInfo
.VERSION 1.0.1
.GUID 635a3105-b4bc-482c-a5f2-ebe7127fd671
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
        Expands the archive without file validation located at
        'C:\ExampleArchivePath\Archive.zip' to the destination path
        'C:\ExampleDestinationPath\Destination'.

        The resource will only check if the expanded archive files exist at the
        destination. No validation is performed on any existing files at the
        destination to ensure that they match the files in the archive.
#>
Configuration xArchive_ExpandArchiveNoValidation_Config
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xArchive Archive3
        {
            Path        = 'C:\ExampleArchivePath\Archive.zip'
            Destination = 'C:\ExampleDestinationPath\Destination'
            Ensure      = 'Present'
        }
    }
}
