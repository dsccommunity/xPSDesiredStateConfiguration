<#PSScriptInfo
.VERSION 1.0.0
.GUID fb673afd-e01d-43fd-8993-6a420182aef3
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/xPSDesiredStateConfiguration/blob/main/LICENSE
.PROJECTURI https://github.com/dsccommunity/xPSDesiredStateConfigurationon
.ICONURI
.EXTERNALMODULEDEPENDENCIES xPSDesiredStateConfiguration
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
#>

#Requires -Module xPSDesiredStateConfiguration

<#
    .DESCRIPTION
        This DSC configuration removes a DSC Pull Server and Compliance Server.
#>
configuration xDscWebService_Removal_Config
{
    Import-DSCResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        WindowsFeature DSCServiceFeature
        {
            Ensure = 'Present'
            Name   = 'DSC-Service'
        }

        xDscWebService PSDSCPullServer
        {
            Ensure                   = 'Absent'
            EndpointName             = 'PSDSCPullServer'
            CertificateThumbPrint    = 'notNeededForRemoval'
            UseSecurityBestPractices = $false
        }
    }
}
