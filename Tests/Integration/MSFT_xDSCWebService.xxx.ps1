######################################################################################
# Integration Tests for DSC Resource xDSCWebService
#
# There tests will make changes to your system, we are tyring to roll them back,
# but you never know. Best to run this on a throwaway VM.
# Run as an elevated administrator
######################################################################################

# Create a unique name that we use for our temp files and folders
[System.String] $tempFolderName = 'xDSCWebServiceTests_' + (Get-Date).ToString("yyyyMMdd_HHmmss")

Describe 'xDSCWebService' {
    function Verify-DSCPullServer
    {
        param
        (
            [Parameter(Mandatory = $true)]
            [System.String]
            $Protocol,

            [Parameter(Mandatory = $true)]
            [System.String]
            $Hostname,

            [Parameter(Mandatory = $true)]
            [System.String]
            $Port
        )

        ([xml](Invoke-WebRequest -Uri "$($Protocol)://$($Hostname):$($Port)/psdscpullserver.svc" | Foreach-Object -Process Content)).service.workspace.collection.href
    }

    try
    {
        # Before doing our changes, create a backup of the current config
        Backup-WebConfiguration -Name $tempFolderName

        It 'Installing Service' -test {
            {
                # Define the configuration
                Configuration InstallingService
                {
                    WindowsFeature DSCServiceFeature
                    {
                        Ensure = 'Present'
                        Name   = 'DSC-Service'
                    }
                }

                $installingServiceMofPath = '{0}\{1}_InstallingService' -f $TestDrive, $tempFolderName

                # Execute the configuration into a temp location
                InstallingService -OutputPath $installingServiceMofPath

                # Run the configuration, it should not throw any errors
                Start-DscConfiguration -Path $installingServiceMofPath -Wait -Verbose -ErrorAction Stop -Force
            } | Should -Not -Throw

            (Get-WindowsFeature -Name DSC-Service | Where-Object -Property Installed -EQ $true).Count | Should -Be 1
        }

        It 'Creating Sites' -Test {
            {
                # Define the configuration
                Configuration CreatingSites
                {
                    Import-DSCResource -ModuleName xPSDesiredStateConfiguration

                    xDscWebService PSDSCPullServer
                    {
                        EndpointName             = 'TestPSDSCPullServer'
                        Port                     = 21001
                        CertificateThumbPrint    = 'AllowUnencryptedTraffic'
                        UseSecurityBestPractices = $true
                    }
                }

                $creatingSitesMofPath = '{0}\{1}_CreatingSites' -f $TestDrive, $tempFolderName

                # Execute the configuration into a temp location
                CreatingSites -OutputPath $creatingSitesMofPath

                # Run the configuration, it should not throw any errors
                Start-DscConfiguration -Path $creatingSitesMofPath -Wait -Verbose -ErrorAction Stop -Force
            } | Should -Not -Throw

            # We now expect two sites starting with our prefix
            (Get-ChildItem -Path IIS:\sites | Where-Object -Property Name -Match "^TestPSDSC").Count | Should -Be 1

            # We expect some files in the web root, using the defaults
            (Test-Path -Path "$ENV:SystemDrive\inetpub\TestPSDSCPullServer\web.config") | Should -Be $true

            $fireWallRuleDisplayName = 'Desired State Configuration - Pull Server Port:{0}'
            $ruleName = ($fireWallRuleDisplayName -f '21001')
            (Get-NetFirewallRule | Where-Object -Name DisplayName -EQ $ruleName | Measure-Object).Count | Should -Be 1

            # We also expect an XML document with certain strings at a certain URI
            Verify-DSCPullServer -Protocol 'http' -Hostname 'localhost' -Port '21001' | Should -Match 'Action|Module'
        }

        It 'Removing Sites' -Test {
            {
                # Define the configuration
                Configuration RemovingSites
                {
                    Import-DSCResource -ModuleName xPSDesiredStateConfiguration

                    xDscWebService PSDSCPullServer
                    {
                        Ensure                   = 'Absent'
                        EndpointName             = 'TestPSDSCPullServer'
                        CertificateThumbPrint    = 'NotUsed'
                        UseSecurityBestPractices = $true
                    }
                }

                $removingSitesMofPath = '{0}\{1}_RemovingSites' -f $TestDrive, $tempFolderName

                # Execute the configuration into a temp location
                RemovingSites -OutputPath $removingSitesMofPath

                # Run the configuration, it should not throw any errors
                Start-DscConfiguration -Path $removingSitesMofPath -Wait -Verbose -ErrorAction Stop -Force
            } | Should -Not -Throw

            # We now expect two sites starting with our prefix
            (Get-ChildItem -Path IIS:\sites | Where-Object Name -match '^TestPSDSC').Count | Should -Be 0

            Test-Path -Path "$ENV:SystemDrive\inetpub\TestPSDSCPullServer\web.config" | Should -Be $false

            $fireWallRuleDisplayName = 'Desired State Configuration - Pull Server Port:{0}'
            $ruleName = ($fireWallRuleDisplayName -f '8081')
            (Get-NetFirewallRule | Where-Object -Property DisplayName -EQ $ruleName | Measure-Object).Count | Should -Be 0
        }

        It 'CreatingSitesWithFTP' -Test {
            {
                # Create a new FTP site on IIS
                If (-not (Test-Path -Path IIS:\Sites\DummyFTPSite))
                {
                    New-WebFtpSite -Name 'DummyFTPSite' -Port '21000'

                    # Stop the site, we don't want it, it is just here to check whether setup works
                    (Get-Website -Name 'DummyFTPSite').ftpserver.stop()
                }

                # Define the configuration
                Configuration CreatingSitesWithFTP
                {
                    Import-DSCResource -ModuleName xPSDesiredStateConfiguration

                    xDscWebService PSDSCPullServer2
                    {
                        EndpointName             = 'TestPSDSCPullServer2'
                        Port                     = 21003
                        CertificateThumbPrint    = 'AllowUnencryptedTraffic'
                        UseSecurityBestPractices = $true
                    }
                }

                $creatingSitesWithFtpMofPath = '{0}\{1}_CreatingSitesWithFTP' -f $TestDrive, $tempFolderName

                # Execute the configuration into a temp location
                CreatingSitesWithFTP -OutputPath $creatingSitesWithFtpMofPath

                # Run the configuration, it should not throw any errors
                Start-DscConfiguration -Path $creatingSitesWithFtpMofPath -Wait -Verbose -ErrorAction Stop -Force
            }  | Should -Not -Throw
        }
    }
    finally
    {
        # Roll back our changes
        Restore-WebConfiguration -Name $tempFolderName
        Remove-WebConfigurationBackup -Name $tempFolderName

        # Remove the generated MoF files
        Get-ChildItem -Path $ENV:TEMP -Filter $tempFolderName | Remove-Item -Recurse -Force

        # Remove all firewall rules starting with port 21*
        Get-NetFirewallRule | Where-Object -Property DisplayName -Match '^Desired State Configuration - Pull Server Port:21' | Remove-NetFirewallRule
    }
}
