<#PSScriptInfo
.VERSION 1.0.1
.GUID 58632bf6-5a7f-4a85-bca6-59795c8aa801
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
        Configuration that install an MSI file.

    .DESCRIPTION
        Configuration that install an MSI file with the specified product
        identification number.

    .PARAMETER ProductId
        The product identification number in the format
        '{DEADBEEF-80C6-41E6-A1B9-8BDB8A05027F}'.

    .PARAMETER Path
        The URI path. Should start with an URI scheme, e.g. 'file://','http://',
        'https://'.

    .NOTES
        When using the file scheme, the MSI file with the given product
        identification number must already exist at the specified path.
        When using the http or https scheme, the MSI file with the given product
        identification number must already exist on the server.

        The product ID and path value in this file are provided for example
        purposes only and will need to be replaced with valid values.

        You can run the following command to get a list of all available MSI's on
        your system with the correct Path (LocalPackage) and product ID (IdentifyingNumber):

        Get-WmiObject Win32_Product | Format-Table IdentifyingNumber, Name, LocalPackage

    .EXAMPLE
        xMsiPackage_InstallPackageConfig -ProductId '{DEADBEEF-80C6-41E6-A1B9-8BDB8A05027F}' -Path 'file://Examples/example.msi'

        Compiles a configuration that installs the MSI package located at
        the path 'file://Examples/example.msi' having the product identification
        number as '{DEADBEEF-80C6-41E6-A1B9-8BDB8A05027F}'.

    .EXAMPLE
        xMsiPackage_InstallPackageConfig -ProductId '{DEADBEEF-80C6-41E6-A1B9-8BDB8A05027F}' -Path 'http://Examples/example.msi'

        Compiles a configuration that installs the MSI package located at
        the URL 'http://Examples/example.msi' having the product identification
        number as '{DEADBEEF-80C6-41E6-A1B9-8BDB8A05027F}'.
#>
Configuration xMsiPackage_InstallPackageConfig
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ProductId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xMsiPackage MsiPackage1
        {
            ProductId = $ProductId
            Path      = $Path
            Ensure    = 'Present'
        }
    }
}
