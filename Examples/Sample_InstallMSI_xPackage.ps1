<#
Simple installer for an msi package that matches via the Name.
#>
Configuration Example
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $PackageName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $SourcePath
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xPackage t1
        {
            Ensure    = "Present"
            Name      = $PackageName
            Path      = $SourcePath
            ProductId = ""
        }
    }
}

<#
Sample use (parameter values need to be changed according to your scenario):

# Create the MOF file using the configuration data
Sample -OutputPath $OutputPath -ConfigurationData $Global:AllNodes -PackageName "Package Name" -SourcePath "\\software\installer.msi"

#>
