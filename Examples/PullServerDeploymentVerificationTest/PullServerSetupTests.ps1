<#
 *
 * Once you setup your pull server with registration, run the following set of tests on the pull server machine
 * to verify if the pullserver is setup properly and ready to go.
 #>

<#
 * Prerequisites:
 * You need Pester module to run this test.
 * With PowerShell 5, use Install-Module Pester to install the module if it is not on pull server node.
 * With older PowerShell, install PackageManagement extensions first.
 #>

<#
 * Run the test via Invoke-Pester ./PullServerSetupTests.ps1
 * This test assumes default values are used during deployment for the location of web.config and pull server URL.
 * If default values are not used during deployment , please update these values in the 'BeforeAll' block accordingly.
 #>


Describe PullServerInstallationTests {
    BeforeAll{
 
        # UPDATE THE PULLSERVER URL, If it is different from the default value.
        $HostFQDN = [System.Net.Dns]::GetHostEntry([string]$env:computername).HostName
        $PullServerURL = "https://$($HostFQDN):8080/PSDSCPullserver.svc"

        # UPDATE THE LOCATION OF WEB.CONFIG, if it is differnet from the default path.
        $DefaultPullServerConfigFile = "$($env:SystemDrive)\inetpub\wwwroot\psdscpullserver\web.config"

        # Skip all tests if web.config is not found
        if (-not (Test-Path $DefaultPullServerConfigFile)){
            Write-Error "No pullserver web.config found." -ErrorAction Stop
        }

        # Get web.config content as XML
        $WebConfigXML = [xml](Get-Content $DefaultPullServerConfigFile)

        # Registration Keys info.
        $RegKeyFile = "RegistrationKeys.txt"
        $DscRegKeyXMLNode = $WebConfigXML.SelectNodes("//appSettings/add[@key = 'RegistrationKeyPath']")
        $RegKeyPath = Join-Path $DscRegKeyXMLNode.value $RegKeyFile
        $RegKey = Get-Content $RegKeyPath

        # Configuration repository info.
        $DscConfigPathXMLNode = "//appSettings/add[@key = 'ConfigurationPath']"
        $DscConfigPath  = ($WebConfigXML.SelectNodes($DscConfigPathXMLNode)).value

        # Module repository info.
        $DscModulePathXMLNode = "//appSettings/add[@key = 'ModulePath']"
        $DscModulePath = ($WebConfigXML.SelectNodes($DscModulePathXMLNode)).value

        # Testing Files/Variables
        $DscTestMetaConfigPath = "$PSScriptRoot\PullServerSetupTestMetaConfig"
        $DscTestConfigName = "PullServerSetUpTest"
        $DscTestMofPath = "$DscConfigPath/$DscTestConfigName.mof"
    }
    Context "Verify general pull server functionality" {
        It "$RegKeyPath exists" {
            $RegKeyPath | Should Exist
        }
        It "Module repository $DscModulePath exists" {
            $DscModulePath | Should Exist 
        }
        It "Configuration repository $DscConfigPath exists" {
            $DscConfigPath | Should Exist 
        }
        It "Verify server $PullServerURL is up and running" {
            $response = Invoke-WebRequest -Uri $PullServerURL -UseBasicParsing
            $response.StatusCode | Should Be 200
        }
    }
    Context "Verify pull end to end works" {
        It 'Tests local configuration manager' {
            [DscLocalConfigurationManager()]
            Configuration PullServerSetUpTestMetaConfig
            {
                Settings
                {
                    RefreshMode = "PULL"             
                }
                ConfigurationRepositoryWeb ConfigurationManager
                {
                    ServerURL =  $PullServerURL
                    RegistrationKey = $RegKey
                    ConfigurationNames = @($DscTestConfigName)
                }
            }

            PullServerSetUpTestMetaConfig -OutputPath $DscTestMetaConfigPath
            Set-DscLocalConfigurationManager -Path $DscTestMetaConfigPath -Verbose:$VerbosePreference -Force

            $DscLocalConfigNames = (Get-DscLocalConfigurationManager).ConfigurationDownloadManagers.ConfigurationNames
            $DscLocalConfigNames -contains $DscTestConfigName | Should Be True
        }
        It "Creates mof and checksum files in $DscConfigPath" {
            # Sample test configuration 
            Configuration NoOpConfig {
                Import-DscResource -ModuleName PSDesiredStateConfiguration
                Node ($DscTestConfigName)
                {
                    Script script
                    {
                        GetScript = "@{}"
                        SetScript = "{}"            
                        TestScript =  {
                            if ($false) { return $true } else {return $false}
                        }
                    }
                }
            }

            # Create a mof file copy it to 
            NoOpConfig -OutputPath $DscConfigPath -Verbose:$VerbosePreference
            $DscTestMofPath | Should Exist

            # Create checksum 
            New-DscChecksum $DscConfigPath -Verbose:$VerbosePreference -Force
            "$DscTestMofPath.checksum" | Should Exist
        }
        It 'Updates DscConfiguration Successfully' {
            Update-DscConfiguration -Wait -Verbose:$VerbosePreference 
            (Get-DscConfiguration).ConfigurationName | Should Be "NoOpConfig"
        }
    }
}
