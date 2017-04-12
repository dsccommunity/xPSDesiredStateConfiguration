<#
    .SYNOPSIS
        Uninstalls the MSI file with the given ID from an Https server.

        Note that the MSI file with the given Product ID (GUID) must already exist
        on the server.
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
