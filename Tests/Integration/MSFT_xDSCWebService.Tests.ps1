######################################################################################
# Integration Tests for DSC Resource xDSCWebService
# 
# There tests will make changes to your system, even though they also try to roll
# them back.
# Run as an elevated administrator 
######################################################################################

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# create a unique name that we use for our temp files and folders
[string]$tempName = "xDSCWebServiceTests_" + (Get-Date).ToString("yyyyMMdd_HHmmss")

Describe "xDSCWebService" {

    function Verify-DSCPullServer ($protocol,$hostname,$port) {
        ([xml](invoke-webrequest "$($protocol)://$($hostname):$($port)/psdscpullserver.svc" | % Content)).service.workspace.collection.href
    }

    function Remove-WebRoot([string]$filePath)
    {
       if (Test-Path $filePath)
       {
           Get-ChildItem $filePath -Recurse | Remove-Item -Recurse
           Remove-Item $filePath
       }
    }

    try
    {
        # before doing our changes, create a backup of the current config        
        Backup-WebConfiguration -Name $tempName


        It 'Installing Service' -test {
        {
            # define the configuration
            configuration InstallingService
            {
                WindowsFeature DSCServiceFeature
                {
                    Ensure = “Present”
                    Name   = “DSC-Service”
                }
            }

            # execute the configuration into a temp location
            InstallingService -OutputPath $env:temp\$($tempName)_InstallingService
            # run the configuration, it should not throw any errors
            Start-DscConfiguration -Path $env:temp\$($tempName)_InstallingService -Wait -Verbose -ErrorAction Stop -Force}  | should not throw

            (Get-WindowsFeature -name DSC-Service | Where Installed).count | should be 1
        }

        It 'Creating Sites' -test {
        {

            # define the configuration
            configuration CreatingSites
            {
                Import-DSCResource -ModuleName xPSDesiredStateConfiguration

                xDscWebService PSDSCPullServer
                {
                    EndpointName            = “TestPSDSCPullServer”
                    Port                    = 8081
                    CertificateThumbPrint   = “AllowUnencryptedTraffic”
                }

                xDscWebService PSDSCComplianceServer
                {
                    EndpointName            = “TestPSDSCComplianceServer”
                    Port                    = 9081
                    CertificateThumbPrint   = “AllowUnencryptedTraffic”
                    IsComplianceServer      = $true
                }
            }

            # execute the configuration into a temp location
            CreatingSites -OutputPath $env:temp\$($tempName)_CreatingSites
            # run the configuration, it should not throw any errors
            Start-DscConfiguration -Path $env:temp\$($tempName)_CreatingSites -Wait -Verbose -ErrorAction Stop -Force}  | should not throw

            # we now expect two sites starting with our prefix
            (Get-ChildItem iis:\sites | Where-Object Name -match "^TestPSDSC").count | should be 2

            # we expect some files in the web root, using the defaults
            (Test-Path "$env:SystemDrive\inetpub\TestPSDSCPullServer\web.config") | should be $true

            $FireWallRuleDisplayName = "Desired State Configuration - Pull Server Port:{0}"
            $ruleName = ($($FireWallRuleDisplayName) -f "8081")
            (Get-NetFirewallRule | Where-Object DisplayName -eq "$ruleName" | Measure-Object).count | should be 1

            # we also expect an XML document with certain strings at a certain URI
            (Verify-DSCPullServer "http" "localhost" "8081") | should match "Action|Module"

        }

        It 'Removing Sites' -test {
        {

            # define the configuration
            configuration RemovingSites
            {
                Import-DSCResource -ModuleName xPSDesiredStateConfiguration

                xDscWebService PSDSCPullServer
                {
                    Ensure                  = “Absent”
                    EndpointName            = “TestPSDSCPullServer”
                    CertificateThumbPrint   = “NotUsed”
                }

                xDscWebService PSDSCComplianceServer
                {
                    Ensure                  = “Absent”
                    EndpointName            = “TestPSDSCComplianceServer”
                    CertificateThumbPrint   = “NotUsed”
                }
            }

            # execute the configuration into a temp location
            RemovingSites -OutputPath $env:temp\$($tempName)_RemovingSites
            # run the configuration, it should not throw any errors
            Start-DscConfiguration -Path $env:temp\$($tempName)_RemovingSites -Wait -Verbose -ErrorAction Stop -Force}  | should not throw

            # we now expect two sites starting with our prefix
            (Get-ChildItem iis:\sites | Where-Object Name -match "^TestPSDSC").count | should be 0

            (Test-Path "$env:SystemDrive\inetpub\TestPSDSCPullServer\web.config") | should be $false

            $FireWallRuleDisplayName = "Desired State Configuration - Pull Server Port:{0}"
            $ruleName = ($($FireWallRuleDisplayName) -f "8081")
            (Get-NetFirewallRule | Where-Object DisplayName -eq "$ruleName" | Measure-Object).count | should be 0

        }

    }
    finally
    {
        # roll back our changes
        Restore-WebConfiguration -Name $tempName
        Remove-WebConfigurationBackup -Name $tempName

        # remove possible web files
        Remove-WebRoot -filePath "$env:SystemDrive\inetpub\TestPSDSCPullServer"
        Remove-WebRoot -filePath "$env:SystemDrive\inetpub\TestPSDSCComplianceServer"

        # remove the generated MoF files
        Get-ChildItem $env:temp -Filter $tempName* | Remove-item -Recurse
    } 
}