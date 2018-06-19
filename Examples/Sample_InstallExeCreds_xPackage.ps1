<#
Simple package that installs an .exe using credentials to access the installer and specifying RunAs Credentials.

#>

Configuration Example
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $SourcePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ProductId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        $Credential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        $RunAsCredential
    )


    Import-DscResource -Module xPSDesiredStateConfiguration

    Node localhost
    {
        xPackage t1
        {
            Ensure          = "Present"
            Name            = $PackageName
            Path            = $SourcePath
            RunAsCredential = $RunAsCredential
            Credential      = $Credential
            ProductId       = $ProductId
        }
    }
}



<#
Sample use (parameter values need to be changed according to your scenario):

# Create the MOF file using the configuration data
Sample -OutputPath $OutputPath -ConfigurationData $Global:AllNodes -PackageName "Package Name" -SourcePath "\\software\installer.exe" -ProductId "" `
    -Credential $Credential -RunAsCredential $RunAsCredential

#>

