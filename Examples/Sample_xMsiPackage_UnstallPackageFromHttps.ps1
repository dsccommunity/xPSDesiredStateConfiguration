<#
    .SYNOPSIS
        Uninstalls the MSI file with the product ID: '{DEADBEEF-80C6-41E6-A1B9-8BDB8A05027F}'
        at the path: 'https://Examples/example.msi'.

        Note that the MSI file with the given product ID must already exist on the server.
        The product ID and path value in this file are provided for example purposes only and will
        need to be replaced with valid values.
#>
Configuration Sample_xMsiPackage_UninstallPackageFromHttps
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xMsiPackage MsiPackage1
        {
            ProductId = '{DEADBEEF-80C6-41E6-A1B9-8BDB8A05027F}'
            Path = 'https://Examples/example.msi'
            Ensure = 'Absent'
        }
    }
}
