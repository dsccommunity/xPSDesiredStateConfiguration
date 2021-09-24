<#PSScriptInfo
.VERSION 1.0.0
.GUID 33db3573-eeca-479e-9b91-b9578b6b0285
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/xPSDesiredStateConfiguration/blob/main/LICENSE
.PROJECTURI https://github.com/dsccommunity/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES NetworkingDsc, xPSDesiredStateConfiguration
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
#>

#Requires -Module xPSDesiredStateConfiguration
#Requires -Module @{ ModuleName = 'NetworkingDsc'; RequiredVersion = '7.4.0.0' }

<#
    .DESCRIPTION
        This configuration sets up a DSC pull server that is capable for client nodes
        to register with it and use SQL Server as a backend DB.

        Prerequisite: 1 - Install a certificate in 'CERT:\LocalMachine\MY\'
                          store. For testing environments, you could use a
                          self-signed certificate. (New-SelfSignedCertificate
                          cmdlet could generate one for you). For production
                          environments, you will need a certificate signed by
                          valid CA. Registration only works over https
                          protocols. So to use registration feature, a secure
                          pull server setup with certificate is necessary.
                      2 - Install and Configure SQL Server, preferably using
                          [SqlServerDsc](https://github.com/PowerShell/SqlServerDsc)
                      3 - To configure a Firewall Rule (Exception) to allow external
                          connections the [NetworkingDsc](https://github.com/PowerShell/NetworkingDsc)
                          DSC module is required.

    .PARAMETER CertificateThumbPrint
        Certificate thumbprint for creating an HTTPS endpoint. Use
        "AllowUnencryptedTraffic" for setting up a non SSL based endpoint.

    .PARAMETER RegistrationKey
        This key will be used by client nodes as a shared key to authenticate
        during registration. This should be a string with enough entropy
        (randomness) to protect the registration of clients to the pull server.
        The example creates a new GUID for the registration key.

    .PARAMETER Port
        The TCP port on which the Pull Server will listen for connections

    .EXAMPLE
        $thumbprint = (New-SelfSignedCertificate -Subject $env:COMPUTERNAME).Thumbprint
        $registrationKey = [System.Guid]::NewGuid()

        xDscWebService_RegistrationUseSQLProvider_Config -RegistrationKey $registrationKey -CertificateThumbPrint $thumbprint -Verbose
#>
Configuration xDscWebService_RegistrationUseSQLProvider_Config
{
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateThumbPrint,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $RegistrationKey,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [System.UInt16]
        $Port = 8080
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName NetworkingDsc -ModuleVersion 7.4.0.0
    # To explicitly import the resource WindowsFeature and File.
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node localhost
    {
        WindowsFeature DSCServiceFeature
        {
            Ensure = 'Present'
            Name   = 'DSC-Service'
        }

        xDscWebService PSDSCPullServer
        {
            Ensure                       = 'Present'
            EndpointName                 = 'PSDSCPullServer'
            Port                         = $Port
            PhysicalPath                 = "$env:SystemDrive\inetpub\PSDSCPullServer"
            CertificateThumbPrint        = $CertificateThumbPrint
            ModulePath                   = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
            ConfigurationPath            = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
            State                        = 'Started'
            DependsOn                    = '[WindowsFeature]DSCServiceFeature'
            RegistrationKeyPath          = "$env:PROGRAMFILES\WindowsPowerShell\DscService"
            AcceptSelfSignedCertificates = $true
            UseSecurityBestPractices     = $true
            SqlProvider                  = $true
            SqlConnectionString          = "Provider=SQLNCLI11;Data Source=(local)\SQLExpress;User ID=SA;Password=Password12!;Initial Catalog=master;"
            ConfigureFirewall            = $false
        }

        File RegistrationKeyFile
        {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $RegistrationKey
        }

        Firewall PSDSCPullServerRule
        {
            Ensure      = 'Present'
            Name        = "DSC_PullServer_$Port"
            DisplayName = "DSC PullServer $Port"
            Group       = 'DSC PullServer'
            Enabled     = $true
            Action      = 'Allow'
            Direction   = 'InBound'
            LocalPort   = $Port
            Protocol    = 'TCP'
            DependsOn   = '[xDscWebService]PSDSCPullServer'
        }

    }
}
