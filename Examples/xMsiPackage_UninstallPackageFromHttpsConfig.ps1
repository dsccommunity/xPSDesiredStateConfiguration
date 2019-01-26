<#PSScriptInfo
.VERSION 1.0.1
.GUID 6492da05-37f4-47c3-9c72-19da8983dfa0
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
        Uninstalls the MSI file with the product ID using a file that is
        accessed through an URL.

    .DESCRIPTION
        Uninstalls the MSI file with the product ID: '{DEADBEEF-80C6-41E6-A1B9-8BDB8A05027F}'
        at the path: 'https://Examples/example.msi'.

    .NOTES
        The MSI file with the given product ID must already exist on
        the server.

        The product ID and path value in this file are provided for
        example purposes only and will need to be replaced with valid values.

        You can run the following command to get a list of all available MSI's
        on your system with the correct Path (LocalPackage) and product ID
        (IdentifyingNumber):

        Get-WmiObject Win32_Product | Format-Table IdentifyingNumber, Name, LocalPackage

#>
Configuration xMsiPackage_UninstallPackageFromHttpsConfig
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xMsiPackage 'UninstallMsiPackageFromHttps'
        {
            ProductId = '{DEADBEEF-80C6-41E6-A1B9-8BDB8A05027F}'
            Path      = 'https://Examples/example.msi'
            Ensure    = 'Absent'
        }
    }
}
