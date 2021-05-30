<#PSScriptInfo
.VERSION 1.0.1
.GUID 596fd9ca-7c00-4aa3-8efc-8e77c96942bf
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
        Configuration that installs an .msi that matches via the Name.

    .PARAMETER PackageName
        The name of the package to install.

    .PARAMETER Path
        The path to the executable to install.

    .PARAMETER IgnoreReboot
        Ignore a pending reboot if requested by package installation.

    .EXAMPLE
        xPackage_InstallMsi_Config -PackageName 'Package Name' -Path '\\software\installer.msi'

        Compiles a configuration that installs a package named 'Package Name'
        located in the path '\\software\installer.msi'. Ignore a pending reboot
        if `IgnoreReboot` switch is provided.
#>
Configuration xPackage_InstallMsi_Config
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $PackageName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Switch]
        $IgnoreReboot
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xPackage InstallMsi
        {
            Ensure       = 'Present'
            Name         = $PackageName
            Path         = $Path
            ProductId    = ''
            IgnoreReboot = $IgnoreReboot
        }
    }
}
