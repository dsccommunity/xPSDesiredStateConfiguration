<#
    .SYNOPSIS
        Uninstalls the MSI file with the given ID at the given path.

        Note that the MSI file with the given Product ID (GUID) must already exist
        at the specified path.
#>
Configuration Sample_xMsiPackage_UninstallPackageFromFile
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xMsiPackage MsiPackage1
        {
            ProductId = '{DEADBEEF-80C6-41E6-A1B9-8BDB8A05027F}'
            Path = 'file://Examples/example.msi'
            Ensure = 'Absent'
        }
    }
}
