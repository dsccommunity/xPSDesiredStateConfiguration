<#
    Simple package that installs an .exe using credentials to access the installer and specifying RunAs Credentials.
    This sample also uses custom registry data to discover the package.
#>
Configuration Example
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $Package,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $Source,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [String] $ProductId,

        [boolean] $CreateCheckRegValue = $false,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $InstalledCheckRegKey,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $InstalledCheckRegValueName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $InstalledCheckRegValueData,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $Credential,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $RunAsCredential,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [String] $Arguments
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xPackage t1
        {
            Ensure                     = "Present"
            Name                       = $Package
            Path                       = $Source
            Arguments                  = $Arguments
            RunAsCredential            = $RunAsCredential
            Credential                 = $Credential
            ProductId                  = $ProductId
            CreateCheckRegValue        = $CreateCheckRegValue
            InstalledCheckRegKey       = $InstalledCheckRegKey
            InstalledCheckRegValueName = $InstalledCheckRegValueName
            InstalledCheckRegValueData = $InstalledCheckRegValueData
        }
    }
}

<#
Sample use (parameter values need to be changed according to your scenario):
The reg key and value is created by xPacakage.

# Create the MOF file using the configuration data
Sample -OutputPath $OutputPath -ConfigurationData $Global:AllNodes -Package "Package Name" -Source "\\software\installer.exe" `
    -InstalledCheckRegKey "SOFTWARE\Microsoft\DevDiv\winexpress\Servicing\12.0\coremsi" `
    -InstalledCheckRegValueName "Install" -InstalledCheckRegValueData "1" `
    -CreateCheckRegValue $true
    -Credential $Credential -RunAsCredential $RunAsCredential `
    -Arguments "/q" -ProductId ""

#>
