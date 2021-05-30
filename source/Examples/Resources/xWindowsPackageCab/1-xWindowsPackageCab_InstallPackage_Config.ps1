<#PSScriptInfo
.VERSION 1.0.1
.GUID 6f363fbb-2d4b-4f39-8cfb-4dbff4bd04f6
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
        Installs a package from the cab file with the specified name from the
        specified source path and outputs a log to the specified log path.

    .PARAMETER Name
        The name of the package to install.

    .PARAMETER SourcePath
        The path to the cab file to install the package from.

    .PARAMETER LogPath
        The path to a file to log the install operation to.

    .NOTES
        The DISM PowerShell module must be available on the target machine.

    .EXAMPLE
        xWindowsPackageCab_InstallPackage_Config -Name 'MyPackage' -SourcePath 'C:\MyPackage.cab' -LogPath 'C:\Log\MyPackage.log'

        Compiles a configuration that installs a package named 'MyPackage' from
        the path 'C:\MyPackage.cab', and logs the operation in 'C:\Log\MyPackage.log'.
#>
Configuration xWindowsPackageCab_InstallPackage_Config
{
    param
    (
        [Parameter (Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter (Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SourcePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $LogPath
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xWindowsPackageCab WindowsPackageCab
        {
            Name       = $Name
            Ensure     = 'Present'
            SourcePath = $SourcePath
            LogPath    = $LogPath
        }
    }
}
