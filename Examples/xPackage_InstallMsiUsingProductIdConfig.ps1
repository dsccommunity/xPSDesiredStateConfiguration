<#PSScriptInfo
.VERSION 1.0.1
.GUID fd8e2fd1-7539-4d6c-a203-e88a99e7195d
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
        Configuration that installs an .msi and matches based on the product id.

    .DESCRIPTION
        Configuration that installs an .msi and matches based on the product id.

    .PARAMETER PackageName
        The name of the package to install.

    .PARAMETER Path
        The path to the executable to install.

    .PARAMETER ProductId
        The product identification number of the package (usually a GUID).
        This parameter accepts an empty System.String.

    .EXAMPLE
        xPackage_InstallMsiConfig -PackageName 'Package Name' -Path '\\software\installer.msi' -ProductId '{F06FB2D7-C22C-4987-9545-7C3B15BBBD60}'

        Compiles a configuration that installs a package named 'Package Name'
        located in the path '\\software\installer.msi', witht he product
        identification number '{F06FB2D7-C22C-4987-9545-7C3B15BBBD60}'.
#>
Configuration xPackage_InstallMsiUsingProductIdConfig
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $PackageName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ProductId
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xPackage 'InstallMsi'
        {
            Ensure    = "Present"
            Name      = $PackageName
            Path      = $Path
            ProductId = $ProductId
        }
    }
}
