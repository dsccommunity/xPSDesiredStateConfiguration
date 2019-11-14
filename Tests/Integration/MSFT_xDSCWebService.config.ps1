# Suppressing this rule since ConfigurationData is used by external scripts
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

#region HEADER
# Integration Test Config Template Version: 1.2.0
#endregion

$configFile = [System.IO.Path]::ChangeExtension($MyInvocation.MyCommand.Path, 'json')
if (Test-Path -Path $configFile)
{
    $ConfigurationData = Get-Content -Path $configFile | ConvertFrom-Json
}
else
{
    $ConfigurationData = @{
        AllNodes = @(
            @{
                NodeName              = 'localhost'
                CertificateFile       = $env:DscPublicCertificatePath
                CertificateThumbprint = $env:DscCertificateThumbprint
                ConfigurationPath     = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
                EndpointName          = 'PSDSCPullServer'
                ModulePath            = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
                PhysicalPath          = "$env:SystemDrive\inetpub\PSDSCPullServer"
                Port                  = 8080
                RegistrationKeyPath   = "$env:PROGRAMFILES\WindowsPowerShell\DscService"
            }
        )
    }
}

<#
    .SYNOPSIS
        Removes a configured DSC pull server
#>
Configuration MSFT_xDSCWebService_PullTestRemoval_Config
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    node $AllNodes.NodeName
    {
        xDSCWebService Integration_Test
        {
            Ensure                       = 'Absent'
            AcceptSelfSignedCertificates = $true
            CertificateThumbPrint        = $Node.CertificateThumbprint
            ConfigurationPath            = $Node.ConfigurationPath
            Enable32BitAppOnWin64        = $false
            EndpointName                 = $Node.EndpointName
            ModulePath                   = $Node.ModulePath
            Port                         = $Node.Port
            PhysicalPath                 = $Node.PhysicalPath
            RegistrationKeyPath          = $Node.RegistrationKeyPath
            State                        = 'Started'
            UseSecurityBestPractices     = $true
        }
    }
}

<#
    .SYNOPSIS
        Sets up a DSC pull server using security best practices
#>
Configuration MSFT_xDSCWebService_PullTestWithSecurityBestPractices_Config
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    node $AllNodes.NodeName
    {
        xDSCWebService Integration_Test
        {
            Ensure                       = 'Present'
            AcceptSelfSignedCertificates = $true
            CertificateThumbPrint        = $Node.CertificateThumbprint
            ConfigurationPath            = $Node.ConfigurationPath
            Enable32BitAppOnWin64        = $false
            EndpointName                 = $Node.EndpointName
            ModulePath                   = $Node.ModulePath
            Port                         = $Node.Port
            PhysicalPath                 = $Node.PhysicalPath
            RegistrationKeyPath          = $Node.RegistrationKeyPath
            State                        = 'Started'
            UseSecurityBestPractices     = $true
        }
    }
}

<#
    .SYNOPSIS
        Sets up a DSC pull server without using security best practices
#>
Configuration MSFT_xDSCWebService_PullTestWithoutSecurityBestPractices_Config
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    node $AllNodes.NodeName
    {
        xDSCWebService Integration_Test
        {
            Ensure                       = 'Present'
            AcceptSelfSignedCertificates = $true
            CertificateThumbPrint        = $Node.CertificateThumbprint
            ConfigurationPath            = $Node.ConfigurationPath
            Enable32BitAppOnWin64        = $false
            EndpointName                 = $Node.EndpointName
            ModulePath                   = $Node.ModulePath
            Port                         = $Node.Port
            PhysicalPath                 = $Node.PhysicalPath
            RegistrationKeyPath          = $Node.RegistrationKeyPath
            State                        = 'Started'
            UseSecurityBestPractices     = $false
        }
    }
}

<#
    .SYNOPSIS
        Sets up a DSC pull server without firewall exceptions
#>
Configuration MSFT_xDSCWebService_PullTestWithoutFirewall_Config
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    node $AllNodes.NodeName
    {
        xDSCWebService Integration_Test
        {
            Ensure                       = 'Present'
            AcceptSelfSignedCertificates = $true
            CertificateThumbPrint        = $Node.CertificateThumbprint
            ConfigurationPath            = $Node.ConfigurationPath
            Enable32BitAppOnWin64        = $false
            EndpointName                 = $Node.EndpointName
            ModulePath                   = $Node.ModulePath
            Port                         = $Node.Port
            PhysicalPath                 = $Node.PhysicalPath
            RegistrationKeyPath          = $Node.RegistrationKeyPath
            State                        = 'Started'
            UseSecurityBestPractices     = $true
            ConfigureFirewall            = $false
        }
    }
}

<#
    .SYNOPSIS
        Sets up a DSC pull server with a separate firewall rule definition
#>
Configuration MSFT_xDSCWebService_PullTestWithSeparateFirewallRule_Config
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'NetworkingDsc'

    node $AllNodes.NodeName
    {

        xDSCWebService Integration_Test
        {
            Ensure                       = 'Present'
            AcceptSelfSignedCertificates = $true
            CertificateThumbPrint        = $Node.CertificateThumbprint
            ConfigurationPath            = $Node.ConfigurationPath
            Enable32BitAppOnWin64        = $false
            EndpointName                 = $Node.EndpointName
            ModulePath                   = $Node.ModulePath
            Port                         = $Node.Port
            PhysicalPath                 = $Node.PhysicalPath
            RegistrationKeyPath          = $Node.RegistrationKeyPath
            State                        = 'Started'
            UseSecurityBestPractices     = $true
            ConfigureFirewall            = $false
        }

        Firewall PSDSCPullServerRule
        {
            Ensure      = 'Present'
            Name        = "DSC_PullServer_$($Node.Port)"
            DisplayName = "DSC PullServer $($Node.Port)"
            Group       = 'DSC PullServer'
            Enabled     = $true
            Action      = 'Allow'
            Direction   = 'InBound'
            LocalPort   = $Node.Port
            Protocol    = 'TCP'
            DependsOn   = '[xDscWebService]Integration_Test'
        }

    }
}

<#
    .SYNOPSIS
        Sets up a DSC pull server with an separately defined application pool
#>
Configuration MSFT_xDSCWebService_PullTestSeparateAppPool_Config
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xWebAdministration'

    node $AllNodes.NodeName
    {

        $ApplicationPool_Name = "PSDSCPullServer_$($Node.EndpointName)"

        xWebAppPool PSDSCPullServerPool
        {
            Ensure       = 'Present'
            Name         = $ApplicationPool_Name
            IdentityType = 'NetworkService'
        }

        xDSCWebService Integration_Test
        {
            Ensure                       = 'Present'
            AcceptSelfSignedCertificates = $true
            CertificateThumbPrint        = $Node.CertificateThumbprint
            ConfigurationPath            = $Node.ConfigurationPath
            Enable32BitAppOnWin64        = $false
            ApplicationPoolName          = $ApplicationPool_Name
            EndpointName                 = $Node.EndpointName
            ModulePath                   = $Node.ModulePath
            Port                         = $Node.Port
            PhysicalPath                 = $Node.PhysicalPath
            RegistrationKeyPath          = $Node.RegistrationKeyPath
            State                        = 'Started'
            UseSecurityBestPractices     = $true
            ConfigureFirewall            = $false
            DependsOn                    = '[xWebAppPool]PSDSCPullServerPool'
        }

    }
}
