<#PSScriptInfo
.VERSION 1.0.1
.GUID 4671e4f7-7ba5-4736-8a29-d439db3d9bb7
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
        Disables the Windows optional feature with the specified name and outputs
        a log to the specified path. When the optional feature is disabled, the
        files associated with the feature will also be removed.

    .PARAMETER Name
        The name of the Windows optional feature to disable.

    .PARAMETER LogPath
        The path to the file to log the disable operation to.

    .NOTES
        Can only be run on Windows client operating systems and Windows Server 2012
        or later.
        The DISM PowerShell module must be available on the target machine.

    .EXAMPLE
        xWindowsOptionalFeature_Disable_Config -Name 'SMB1Protocol' -LogPath 'c:\log\feature.log'

        Compiles a configuration that ensures that the SMB1Protocol optional
        feature is disabled, and logs the operation to 'C:\log\feature.log'.
#>
Configuration xWindowsOptionalFeature_Disable_Config
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $LogPath
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xWindowsOptionalFeature DisableOptionalFeature
        {
            Name                 = $Name
            Ensure               = 'Absent'
            LogPath              = $LogPath
            RemoveFilesOnDisable = $true
        }
    }
}
