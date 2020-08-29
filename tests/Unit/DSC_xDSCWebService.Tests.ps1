$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xDSCWebService'

function Invoke-TestSetup
{
    try
    {
        Import-Module -Name DscResource.Test -Force -ErrorAction 'Stop'
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
    }

    $script:testEnvironment = Initialize-TestEnvironment `
        -DSCModuleName $script:dscModuleName `
        -DSCResourceName $script:dscResourceName `
        -ResourceType 'Mof' `
        -TestType 'Unit'

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')
}

function Invoke-TestCleanup
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}

Invoke-TestSetup

# Begin Testing
try
{
    InModuleScope $script:dscResourceName {
        Describe 'xDSCWebService Unit Tests' {
            BeforeAll {
                $script:testParameters = @{
                    ApplicationPoolName      = 'PSWS'
                    CertificateThumbPrint    = 'AllowUnencryptedTraffic'
                    EndpointName             = 'PesterTestSite'
                    UseSecurityBestPractices = $false
                    ConfigureFirewall        = $false
                    Verbose                  = $true
                }

                $script:serviceData = @{
                    ServiceName         = 'PesterTest'
                    ModulePath          = 'C:\Program Files\WindowsPowerShell\DscService\Modules'
                    ConfigurationPath   = 'C:\Program Files\WindowsPowerShell\DscService\Configuration'
                    RegistrationKeyPath = 'C:\Program Files\WindowsPowerShell\DscService'
                    dbprovider          = 'ESENT'
                    dbconnectionstr     = 'C:\Program Files\WindowsPowerShell\DscService\Devices.edb'
                    oleDbConnectionstr  = 'Data Source=TestDrive:\inetpub\PesterTestSite\Devices.mdb'
                }

                $script:websiteDataHTTP  = [System.Management.Automation.PSObject] @{
                    bindings = [System.Management.Automation.PSObject] @{
                        collection = @(
                            @{
                                protocol           = 'http'
                                bindingInformation = '*:8080:'
                                certificateHash    = ''
                            },
                            @{
                                protocol           = 'http'
                                bindingInformation = '*:8090:'
                                certificateHash    = ''
                            }
                        )
                    }
                    physicalPath    = 'TestDrive:\inetpub\PesterTestSite'
                    state           = 'Started'
                    applicationPool = 'PSWS'
                }

                $script:websiteDataHTTPS = [System.Management.Automation.PSObject] @{
                    bindings = [System.Management.Automation.PSObject] @{
                        collection = @(
                            @{
                                protocol           = 'https'
                                bindingInformation = '*:8080:'
                                certificateHash    = 'AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTT'
                            }
                        )
                    }
                    physicalPath    = 'TestDrive:\inetpub\PesterTestSite'
                    state           = 'Started'
                    applicationPool = 'PSWS'
                }

                $script:certificateData  = @(
                    [System.Management.Automation.PSObject] @{
                        Thumbprint = 'AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTT'
                        Subject    = 'PesterTestCertificate'
                        Extensions = [System.Array] @(
                            [System.Management.Automation.PSObject] @{
                                Oid = [System.Management.Automation.PSObject] @{
                                    FriendlyName = 'Certificate Template Name'
                                    Value        = '1.3.6.1.4.1.311.20.2'
                                }
                            }
                            [System.Management.Automation.PSObject] @{}
                        )
                        NotAfter   = Get-Date
                    }
                    [System.Management.Automation.PSObject] @{
                        Thumbprint = 'AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTT'
                        Subject    = 'PesterTestDuplicateCertificate'
                        Extensions = [System.Array] @(
                            [System.Management.Automation.PSObject] @{
                                Oid = [System.Management.Automation.PSObject] @{
                                    FriendlyName = 'Certificate Template Name'
                                    Value        = '1.3.6.1.4.1.311.20.2'
                                }
                            }
                            [System.Management.Automation.PSObject] @{}
                        )
                        NotAfter   = Get-Date
                    }
                    [System.Management.Automation.PSObject] @{
                        Thumbprint = 'AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTT'
                        Subject    = 'PesterTestDuplicateCertificate'
                        Extensions = [System.Array] @(
                            [System.Management.Automation.PSObject] @{
                                Oid = [System.Management.Automation.PSObject] @{
                                    FriendlyName = 'Certificate Template Name'
                                    Value        = '1.3.6.1.4.1.311.20.2'
                                }
                            }
                            [System.Management.Automation.PSObject] @{}
                        )
                        NotAfter   = Get-Date
                    }
                )
                $script:certificateData.ForEach{
                    Add-Member -InputObject $_.Extensions[0] -MemberType ScriptMethod -Name Format -Value {'WebServer'}
                }

                $script:webConfig = @'
<?xml version="1.0"?>
<configuration>
    <appSettings>
    <add key="dbprovider" value="ESENT" />
    <add key="dbconnectionstr" value="TestDrive:\DatabasePath\Devices.edb" />
    <add key="ModulePath" value="TestDrive:\ModulePath" />
    </appSettings>
    <system.webServer>
    <modules>
        <add name="IISSelfSignedCertModule(32bit)" />
    </modules>
    </system.webServer>
</configuration>
'@
            }

            Describe -Name 'DSC_xDSCWebService\Get-TargetResource' -Fixture {
                # Create dummy functions so that Pester is able to mock them
                function Get-Website {}
                function Get-WebBinding {}
                function Stop-Website {}

                $script:webConfigPath = 'TestDrive:\inetpub\PesterTestSite\Web.config'
                $null = New-Item -ItemType Directory -Path (Split-Path -Parent $script:webConfigPath)
                $null = New-Item -Path $script:webConfigPath -Value $script:webConfig

                Context -Name 'When DSC Web Service is not installed' -Fixture {
                    Mock -CommandName Get-WebSite

                    $script:result = $null

                    It 'Should not throw' {
                        {
                            $script:result = Get-TargetResource @script:testParameters
                        } | Should -Not -Throw

                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-WebSite -Scope It
                    }

                    It 'Should return Ensure set to Absent' {
                        $script:result.Ensure | Should -Be 'Absent'
                    }
                }

                #region Mocks
                Mock -CommandName Get-WebSite -MockWith { return $script:websiteDataHTTP }
                Mock -CommandName Get-WebBinding -MockWith {
                    return @{
                        CertificateHash = $script:websiteDataHTTPS.bindings.collection[0].certificateHash
                    }
                }
                Mock -CommandName Get-ChildItem -ParameterFilter {
                    $Path -eq $script:websiteDataHTTP.physicalPath -and $Filter -eq '*.svc'
                } -MockWith {
                    return @{
                        Name = $script:serviceData.ServiceName
                    }
                }
                Mock -CommandName Get-WebConfigAppSetting -ParameterFilter {
                    $AppSettingName -eq 'ModulePath'
                } -MockWith {
                    return $script:serviceData.ModulePath
                }
                Mock -CommandName Get-WebConfigAppSetting -ParameterFilter {
                    $AppSettingName -eq 'ConfigurationPath'
                } -MockWith {
                    return $script:serviceData.ConfigurationPath
                }
                Mock -CommandName Get-WebConfigAppSetting -ParameterFilter {
                    $AppSettingName -eq 'RegistrationKeyPath'
                } -MockWith {
                    return $script:serviceData.RegistrationKeyPath
                }
                Mock -CommandName Get-WebConfigAppSetting -ParameterFilter {
                    $AppSettingName -eq 'dbprovider'
                } -MockWith {
                    return $script:serviceData.dbprovider
                }
                Mock -CommandName Get-WebConfigAppSetting -ParameterFilter {
                    $AppSettingName -eq 'dbconnectionstr'
                } -MockWith {
                    return $script:serviceData.dbconnectionstr
                }
                Mock -CommandName Stop-Website -MockWith {
                    Write-Verbose "MOCK:Stop-WebSite $Name"
                }
                #endregion

                Context -Name 'When DSC Web Service is installed without certificate' -Fixture {
                    $script:result = $null

                    $ipProperties = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()

                    if ($ipProperties.DomainName)
                    {
                        $fqdnComputerName = '{0}.{1}' -f $ipProperties.HostName, $ipProperties.DomainName
                    }
                    else
                    {
                        $fqdnComputerName = $ipProperties.HostName
                    }

                    $testData = @(
                        @{
                            Variable = 'EndpointName'
                            Data     = $script:testParameters.EndpointName
                        }
                        @{
                            Variable = 'Port'
                            Data     = ($script:websiteDataHTTP.bindings.collection[0].bindingInformation -split ':')[1]
                        }
                        @{
                            Variable = 'PhysicalPath'
                            Data     = $script:websiteDataHTTP.physicalPath
                        }
                        @{
                            Variable = 'State'
                            Data     = $script:websiteDataHTTP.state
                        }
                        @{
                            Variable = 'DatabasePath'
                            Data     = Split-Path -Path $script:serviceData.dbconnectionstr -Parent
                        }
                        @{
                            Variable = 'ModulePath'
                            Data     = $script:serviceData.ModulePath
                        }
                        @{
                            Variable = 'ConfigurationPath'
                            Data     = $script:serviceData.ConfigurationPath
                        }
                        @{
                            Variable = 'DSCServerURL'
                            Data     = '{0}://{1}:{2}/{3}' -f $script:websiteDataHTTP.bindings.collection[0].protocol,
                                                                $fqdnComputerName,
                                                                ($script:websiteDataHTTP.bindings.collection[0].bindingInformation -split ':')[1],
                                                                $script:serviceData.ServiceName
                        }
                        @{
                            Variable = 'Ensure'
                            Data     = 'Present'
                        }
                        @{
                            Variable = 'RegistrationKeyPath'
                            Data     = $script:serviceData.RegistrationKeyPath
                        }
                        @{
                            Variable = 'AcceptSelfSignedCertificates'
                            Data     = $true
                        }
                        @{
                            Variable = 'UseSecurityBestPractices'
                            Data     = $false
                        }
                        @{
                            Variable = 'Enable32BitAppOnWin64'
                            Data     = $false
                        }
                    )

                    It 'Should not throw' {
                        {$script:result = Get-TargetResource @script:testParameters} | Should -Not -Throw
                    }

                    It 'Should return <Variable> set to <Data>' -TestCases $testData {
                        param
                        (
                            [Parameter(Mandatory = $true)]
                            [System.String]
                            $Variable,

                            [Parameter(Mandatory = $true)]
                            [System.Management.Automation.PSObject]
                            $Data
                        )

                        if ($null -ne $Data)
                        {
                            $script:result.$Variable  | Should -Be $Data
                        }
                        else
                        {
                            $script:result.$Variable  | Should -BeNull
                        }
                    }

                    It 'Should return ''DisableSecurityBestPractices'' set to $null' {
                        $script:result.DisableSecurityBestPractices | Should -BeNullOrEmpty
                    }

                    It 'Should call expected mocks' {
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-WebSite
                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-WebBinding
                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-ChildItem
                        Assert-MockCalled -Exactly -Times 5 -CommandName Get-WebConfigAppSetting
                    }
                }

                Mock -CommandName Get-WebConfigAppSetting -ParameterFilter {
                    $AppSettingName -eq 'dbconnectionstr'
                } -MockWith {
                    return $script:serviceData.oleDbConnectionstr
                }

                Context -Name 'When DSC Web Service is installed and using OleDb' -Fixture {
                    $script:serviceData.dbprovider = 'System.Data.OleDb'
                    $script:result = $null

                    $testData = @(
                        @{
                            Variable = 'DatabasePath'
                            Data     = $script:serviceData.oleDbConnectionstr
                        }
                    )

                    It 'Should not throw' {
                        {
                            $script:result = Get-TargetResource @script:testParameters
                        } | Should -Not -Throw
                    }

                    It 'Should return <Variable> set to <Data>' -TestCases $testData {
                        param
                        (
                            [Parameter(Mandatory = $true)]
                            [System.String]
                            $Variable,

                            [Parameter(Mandatory = $true)]
                            [System.Management.Automation.PSObject]
                            $Data
                        )

                        $script:result.$Variable | Should -Be $Data
                    }

                    It 'Should call expected mocks' {
                        Assert-VerifiableMock
                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-WebConfigAppSetting -ParameterFilter {
                            $AppSettingName -eq 'dbconnectionstr'
                        }
                    }
                }

                Mock -CommandName Get-WebSite -MockWith {
                    return $script:websiteDataHTTPS
                }
                Mock -CommandName Get-WebBinding -MockWith {
                    return $script:websiteDataHTTPS.bindings.collection
                }
                Mock -CommandName Get-ChildItem -ParameterFilter {
                    $Path -eq 'Cert:\LocalMachine\My\'
                } -MockWith {
                    return $script:certificateData[0]
                }

                Context -Name 'When DSC Web Service is installed with certificate using thumbprint' -Fixture {
                    $altTestParameters = $script:testParameters.Clone()
                    $altTestParameters.CertificateThumbPrint = $script:certificateData[0].Thumbprint
                    $script:result = $null

                    $testData = @(
                        @{
                            Variable = 'CertificateThumbPrint'
                            Data     = $script:certificateData[0].Thumbprint
                        }
                        @{
                            Variable = 'CertificateSubject'
                            Data     = $script:certificateData[0].Subject
                        }
                        @{
                            Variable = 'CertificateTemplateName'
                            Data     = $script:certificateData[0].Extensions.Where{
                                $_.Oid.FriendlyName -eq 'Certificate Template Name'
                            }.Format($false)
                        }
                    )

                    It 'Should not throw' {
                        {
                            $script:result = Get-TargetResource @altTestParameters
                        } | Should -Not -Throw
                    }

                    It 'Should return <Variable> set to <Data>' -TestCases $testData {
                        param
                        (
                            [Parameter(Mandatory = $true)]
                            [System.String]
                            $Variable,

                            [Parameter(Mandatory = $true)]
                            [System.Management.Automation.PSObject]
                            $Data
                        )

                        if ($Data -ne $null)
                        {
                            $script:result.$Variable  | Should -Be $Data
                        }
                        else
                        {
                            $script:result.$Variable  | Should -Be Null
                        }
                    }

                    It 'Should call expected mocks' {
                        Assert-VerifiableMock
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-WebSite
                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-WebBinding
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-ChildItem
                    }
                }

                Context -Name 'When DSC Web Service is installed with certificate using subject' -Fixture {
                    $altTestParameters = $script:testParameters.Clone()
                    $altTestParameters.Remove('CertificateThumbPrint')
                    $altTestParameters.Add('CertificateSubject', $script:certificateData[0].Subject)
                    $script:result = $null

                    $testData = @(
                        @{
                            Variable = 'CertificateThumbPrint'
                            Data     = $script:certificateData[0].Thumbprint
                        }
                        @{
                            Variable = 'CertificateSubject'
                            Data     = $script:certificateData[0].Subject
                        }
                        @{
                            Variable = 'CertificateTemplateName'
                            Data     = $script:certificateData[0].Extensions.Where{$_.Oid.FriendlyName -eq 'Certificate Template Name'}.Format($false)
                        }
                    )

                    It 'Should not throw' {
                        {
                            $script:result = Get-TargetResource @altTestParameters
                        } | Should -Not -Throw
                    }

                    It 'Should return <Variable> set to <Data>' -TestCases $testData {
                        param
                        (
                            [Parameter(Mandatory = $true)]
                            [System.String]
                            $Variable,

                            [Parameter(Mandatory = $true)]
                            [System.Management.Automation.PSObject]
                            $Data
                        )

                        if ($null -ne $Data)
                        {
                            $script:result.$Variable  | Should -Be $Data
                        }
                        else
                        {
                            $script:result.$Variable  | Should -BeNull
                        }
                    }

                    It 'Should call expected mocks' {
                        Assert-VerifiableMock
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-WebSite
                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-WebBinding
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-ChildItem
                    }
                }

                Context -Name 'Function parameters contain invalid data' -Fixture {
                    It 'Should throw if CertificateThumbprint and CertificateSubject are not specifed' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Remove('CertificateThumbPrint')

                        {
                            $script:result = Get-TargetResource @altTestParameters
                        } | Should -Throw
                    }

                    It 'Should throw if CertificateThumbprint and CertificateSubject are both specifed' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Add('CertificateSubject', $script:certificateData[0].Subject)

                        {
                            $script:result = Get-TargetResource @altTestParameters
                        } | Should -Throw
                    }
                }
            }

            Describe -Name 'DSC_xDSCWebService\Set-TargetResource' -Fixture {

                <# Create dummy functions so that Pester is able to mock them #>
                function Get-Website {}
                function Get-WebBinding {}
                function Stop-Website {}
                function New-WebAppPool {}
                function Remove-WebAppPool {}
                function New-WebSite {}
                function Start-Website {}
                function Get-WebConfigurationProperty {}
                function Remove-Website {}

                #region Mocks
                Mock -CommandName Get-Command -ParameterFilter {
                    $Name -eq '.\appcmd.exe'
                } -MockWith {
                    <#
                        We return a ScriptBlock here, so that the ScriptBlock is called with the parameters which are actually passed to appcmd.exe.
                        To verify the arguments which are passed to appcmd.exe the property UnboundArguments of $MyInvocation can be used. But
                        here's a catch: when Powershell parses the arguments into the UnboundArguments it splits arguments which start with -section:
                        into TWO separate array elements. So -section:system.webServer/globalModules ends up in [-section:, system.webServer/globalModules]
                        and not as [-section:system.webServer/globalModules]. If the arguments should later be verified in this mock this should be considered.
                    #>
                    {
                        $allowedArgs = @(
                            '('''' -ne ((& (Get-IISAppCmd) list config -section:system.webServer/globalModules) -like "*$iisSelfSignedModuleName*"))'
                            '& (Get-IISAppCmd) install module /name:$iisSelfSignedModuleName /image:$destinationFilePath /add:false /lock:false'
                            '& (Get-IISAppCmd) add module /name:$iisSelfSignedModuleName /app.name:"$EndpointName/" $preConditionBitnessArgumentFor32BitInstall'
                            '& (Get-IISAppCmd) delete module /name:$iisSelfSignedModuleName /app.name:"$EndpointName/"'
                        )
                        $line = $MyInvocation.Line.Trim() -replace '\s+', ' '

                        if ($allowedArgs -notcontains $line)
                        {
                            throw "Mock test failed. Invalid parameters [$line]"
                        }
                    }
                }
                Mock -CommandName Get-OsVersion -MockWith {
                    @{
                        Major = 6
                        Minor = 3
                    }
                }
                #endregion

                Context -Name 'When DSC Service is not installed and Ensure is Absent' -Fixture {
                    Mock -CommandName Test-Path -ParameterFilter {
                        $LiteralPath -like "IIS:\Sites\*"
                    } -MockWith { $false }
                    Mock -CommandName Remove-PSWSEndpoint
                    Mock -CommandName Remove-PullServerFirewallConfiguration

                    It 'Should call expected mocks' {
                        Set-TargetResource @script:testParameters -Ensure Absent

                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-OsVersion
                        Assert-MockCalled -Exactly -Times 1 -CommandName Test-Path
                        Assert-MockCalled -Exactly -Times 0 -CommandName Remove-PSWSEndpoint
                        Assert-MockCalled -Exactly -Times 0 -CommandName Get-Command
                        Assert-MockCalled -Exactly -Times 0 -CommandName Remove-PullServerFirewallConfiguration
                    }
                }

                Context -Name 'When DSC Service is installed and Ensure is Absent' -Fixture {
                    Mock -CommandName Test-Path -ParameterFilter {
                        $LiteralPath -like "IIS:\Sites\*"
                    } -MockWith {
                        $LiteralPath -eq "IIS:\Sites\$($script:testParameters.EndpointName)"
                    }
                    Mock -CommandName Remove-PSWSEndpoint

                    It 'Should call expected mocks' {
                        Set-TargetResource @script:testParameters -Ensure Absent

                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-OsVersion
                        Assert-MockCalled -Exactly -Times 0 -CommandName Get-Command
                        Assert-MockCalled -Exactly -Times 1 -CommandName Test-Path
                        Assert-MockCalled -Exactly -Times 1 -CommandName Remove-PSWSEndpoint
                    }
                }

                #region MSFT_xDSCWebService Mocks
                Mock -CommandName Get-Culture -MockWith {
                    @{
                        IetfLanguageTag = 'en-NZ'
                        TwoLetterISOLanguageName = 'en'
                    }
                }
                Mock -CommandName Test-Path -MockWith { $true }
                Mock -CommandName Update-LocationTagInApplicationHostConfigForAuthentication
                Mock -CommandName Set-AppSettingsInWebconfig
                Mock -CommandName Set-BindingRedirectSettingInWebConfig
                Mock -CommandName Copy-Item
                Mock -CommandName Test-FilesDiffer -MockWith { $false }
                #endregion

                #region xPSDesiredStateConfiguration.PSWSIIS Mocks
                Mock -CommandName Get-WebConfigurationProperty -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Test-Path -MockWith { $true } -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Test-IISInstall -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Remove-WebAppPool -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Remove-Item -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Copy-PSWSConfigurationToIISEndpointFolder -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName New-WebAppPool -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Set-Item -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Get-Item -ParameterFilter {
                    $Path -like 'IIS:\AppPools*'
                } -MockWith {
                    [PSCustomObject]@{
                        name = Split-Path -Path $Path -Leaf
                        managedRuntimeVersion = 'v4.0'
                        enable32BitAppOnWin64 = $false
                        processModel = [PSCustomObject]@{
                            identityType = 4
                        }
                    }
                } -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Get-ChildItem -ParameterFilter {
                    $Path -eq 'Cert:\LocalMachine\My\'
                } -MockWith {
                    <#
                        We cannot use the existing certificate definitions from $script:certificateData because the
                        mock runs in a different module and thus the variable does not exist
                    #>
                    [System.Management.Automation.PSObject] @{
                        Thumbprint = 'AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTT'
                        Subject    = 'PesterTestDuplicateCertificate'
                        Extensions = [System.Array] @(
                            [System.Management.Automation.PSObject] @{
                                Oid = [System.Management.Automation.PSObject] @{
                                    FriendlyName = 'Certificate Template Name'
                                    Value        = '1.3.6.1.4.1.311.20.2'
                                }
                            }
                            [System.Management.Automation.PSObject] @{}
                        )
                        NotAfter   = Get-Date
                    }
                } -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Get-Item -ParameterFilter {
                    $Path -eq 'CERT:\LocalMachine\MY\AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTT'
                } -MockWith {
                    <#
                        We cannot use the existing certificate definitions from $script:certificateData because the
                        mock runs in a different module and thus the variable does not exist
                    #>
                    [System.Management.Automation.PSObject] @{
                        Thumbprint = 'AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTT'
                        Subject    = 'PesterTestDuplicateCertificate'
                        Extensions = [System.Array] @(
                            [System.Management.Automation.PSObject] @{
                                Oid = [System.Management.Automation.PSObject] @{
                                    FriendlyName = 'Certificate Template Name'
                                    Value        = '1.3.6.1.4.1.311.20.2'
                                }
                            }
                            [System.Management.Automation.PSObject] @{}
                        )
                        NotAfter   = Get-Date
                    }
                } -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName New-WebSite -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName New-SiteID -ModuleName xPSDesiredStateConfiguration.PSWSIIS -MockWith {
                    Get-Random -Maximum 10000 -Minimum 1
                }
                Mock -CommandName New-Item -ParameterFilter { $Path -like 'IIS:*' } -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Remove-Item -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Get-WebBinding -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Remove-Website -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                Mock -CommandName Start-Website -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                #endregion

                Context -Name 'When Ensure is Present' -Fixture {
                    $setTargetPaths = @{
                        DatabasePath        = 'TestDrive:\Database'
                        ConfigurationPath   = 'TestDrive:\Configuration'
                        ModulePath          = 'TestDrive:\Module'
                        RegistrationKeyPath = 'TestDrive:\RegistrationKey'
                    }

                    It 'Should call expected mocks' {
                        Mock -CommandName Get-Website -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                        Mock -CommandName Add-PullServerFirewallConfiguration

                        Set-TargetResource @script:testParameters @setTargetPaths -Ensure Present

                        Assert-MockCalled -Exactly -Times 3 -CommandName Get-Command
                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-Culture
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-Website -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                        Assert-MockCalled -Exactly -Times 3 -CommandName Test-Path
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-OsVersion
                        Assert-MockCalled -Exactly -Times 0 -CommandName Add-PullServerFirewallConfiguration
                        Assert-MockCalled -Exactly -Times 3 -CommandName Update-LocationTagInApplicationHostConfigForAuthentication
                        Assert-MockCalled -Exactly -Times 5 -CommandName Set-AppSettingsInWebconfig
                        Assert-MockCalled -Exactly -Times 1 -CommandName Set-BindingRedirectSettingInWebConfig
                        Assert-MockCalled -Exactly -Times 0 -CommandName Copy-Item
                    }

                    $testCases = $setTargetPaths.Keys.ForEach{
                        @{
                            Name = $_
                            Value = $setTargetPaths.$_
                        }
                    }

                    It 'Should create the <Name> directory' -TestCases $testCases {
                        param
                        (
                            [Parameter(Mandatory = $true)]
                            [System.String]
                            $Name,

                            [Parameter(Mandatory = $true)]
                            [System.String]
                            $Value
                        )

                        Set-TargetResource @script:testParameters @setTargetPaths -Ensure Present

                        Test-Path -Path $Value | Should -BeTrue
                    }
                }

                Context -Name 'When Ensure is Present and OS is downlevel of BLUE' -Fixture {
                    Mock -CommandName Get-OsVersion -MockWith {
                        @{
                            Major = 6
                            Minor = 2
                        }
                    }

                    $setTargetPaths = @{
                        DatabasePath        = 'TestDrive:\Database'
                        ConfigurationPath   = 'TestDrive:\Configuration'
                        ModulePath          = 'TestDrive:\Module'
                        RegistrationKeyPath = 'TestDrive:\RegistrationKey'
                    }

                    It 'Should call expected mocks' {

                        Mock -CommandName Get-Website -MockWith {
                            [PSCustomObject]@{
                                Name = $Name
                                State = 'Stopped'
                                applicationPool = 'PSWS'
                                physicalPath = 'TestDrive:\inetpub\PesterTestSite'
                            }
                        } -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Set-TargetResource @script:testParameters @setTargetPaths -Ensure Present

                        Assert-MockCalled -Exactly -Times 3 -CommandName Get-Command
                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-Culture
                        Assert-MockCalled -Exactly -Times 3 -CommandName Test-Path
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-OsVersion
                        Assert-MockCalled -Exactly -Times 3 -CommandName Update-LocationTagInApplicationHostConfigForAuthentication
                        Assert-MockCalled -Exactly -Times 5 -CommandName Set-AppSettingsInWebconfig
                        Assert-MockCalled -Exactly -Times 0 -CommandName Set-BindingRedirectSettingInWebConfig
                        Assert-MockCalled -Exactly -Times 1 -CommandName Copy-Item
                    }
                }

                Context -Name 'When Ensure is Present and OS is up level of BLUE' -Fixture {
                    Mock -CommandName Get-OsVersion -MockWith {
                        @{
                            Major = 10
                            Minor = 0
                        }
                    }

                    $setTargetPaths = @{
                        DatabasePath        = 'TestDrive:\Database'
                        ConfigurationPath   = 'TestDrive:\Configuration'
                        ModulePath          = 'TestDrive:\Module'
                        RegistrationKeyPath = 'TestDrive:\RegistrationKey'
                    }

                    It 'Should call expected mocks' {
                        Mock -CommandName Get-Website -MockWith {
                            [PSCustomObject]@{
                                Name = $Name
                                State = 'Stopped'
                                applicationPool = 'PSWS'
                                physicalPath = 'TestDrive:\inetpub\PesterTestSite'
                            }
                        } -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Set-TargetResource @script:testParameters @setTargetPaths -Ensure Present

                        Assert-MockCalled -Exactly -Times 3 -CommandName Get-Command
                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-Culture
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-Website -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                        Assert-MockCalled -Exactly -Times 3 -CommandName Test-Path
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-OsVersion
                        Assert-MockCalled -Exactly -Times 3 -CommandName Update-LocationTagInApplicationHostConfigForAuthentication
                        Assert-MockCalled -Exactly -Times 5 -CommandName Set-AppSettingsInWebconfig
                        Assert-MockCalled -Exactly -Times 0 -CommandName Set-BindingRedirectSettingInWebConfig
                        Assert-MockCalled -Exactly -Times 0 -CommandName Copy-Item
                    }
                }

                Context -Name 'When Ensure is Present and Enable32BitAppOnWin64' -Fixture {
                    $setTargetPaths = @{
                        DatabasePath        = 'TestDrive:\Database'
                        ConfigurationPath   = 'TestDrive:\Configuration'
                        ModulePath          = 'TestDrive:\Module'
                        RegistrationKeyPath = 'TestDrive:\RegistrationKey'
                    }

                    It 'Should call expected mocks' {
                        Mock -CommandName Get-Website -MockWith {
                            [PSCustomObject]@{
                                Name = $Name
                                State = 'Stopped'
                                applicationPool = 'PSWS'
                                physicalPath = 'TestDrive:\inetpub\PesterTestSite'
                            }
                        } -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Set-TargetResource @script:testParameters @setTargetPaths -Ensure Present -Enable32BitAppOnWin64 $true

                        Assert-MockCalled -Exactly -Times 3 -CommandName Get-Command
                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-Culture
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-Website -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                        Assert-MockCalled -Exactly -Times 3 -CommandName Test-Path
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-OsVersion
                        Assert-MockCalled -Exactly -Times 3 -CommandName Update-LocationTagInApplicationHostConfigForAuthentication
                        Assert-MockCalled -Exactly -Times 5 -CommandName Set-AppSettingsInWebconfig
                        Assert-MockCalled -Exactly -Times 1 -CommandName Set-BindingRedirectSettingInWebConfig
                        Assert-MockCalled -Exactly -Times 1 -CommandName Copy-Item
                    }
                }

                Context -Name 'When Ensure is Present and AcceptSelfSignedCertificates is $false' -Fixture {
                    $setTargetPaths = @{
                        DatabasePath        = 'TestDrive:\Database'
                        ConfigurationPath   = 'TestDrive:\Configuration'
                        ModulePath          = 'TestDrive:\Module'
                        RegistrationKeyPath = 'TestDrive:\RegistrationKey'
                    }


                    It 'Should call expected mocks' {
                        Mock -CommandName Get-Website -MockWith {
                            [PSCustomObject]@{
                                Name = $Name
                                State = 'Stopped'
                                applicationPool = 'PSWS'
                                physicalPath = 'TestDrive:\inetpub\PesterTestSite'
                            }
                        } -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Set-TargetResource @script:testParameters @setTargetPaths -Ensure Present -AcceptSelfSignedCertificates $false

                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-Command
                        Assert-MockCalled -Exactly -Times 1 -CommandName Get-Culture
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-Website -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                        Assert-MockCalled -Exactly -Times 2 -CommandName Test-Path
                        Assert-MockCalled -Exactly -Times 2 -CommandName Get-OsVersion
                        Assert-MockCalled -Exactly -Times 3 -CommandName Update-LocationTagInApplicationHostConfigForAuthentication
                        Assert-MockCalled -Exactly -Times 5 -CommandName Set-AppSettingsInWebconfig
                        Assert-MockCalled -Exactly -Times 1 -CommandName Set-BindingRedirectSettingInWebConfig
                        Assert-MockCalled -Exactly -Times 0 -CommandName Copy-Item
                    }
                }

                Context -Name 'When Ensure is Present and UseSecurityBestPractices is $true' -Fixture {
                    $altTestParameters = $script:testParameters.Clone()
                    $altTestParameters.UseSecurityBestPractices = $true

                    It 'Should throw an error because no certificate specified' {
                        {
                            Set-TargetResource @altTestParameters -Ensure Present
                        } | Should -Throw -ExpectedMessage $script:LocalizedData.InvalidUseSecurityBestPractice
                    }
                }

                Mock -CommandName Find-CertificateThumbprintWithSubjectAndTemplateName -MockWith {
                    $script:certificateData[0].Thumbprint
                }

                Context -Name 'When Ensure is Present and CertificateSubject is set' -Fixture {
                    $altTestParameters = $script:testParameters.Clone()
                    $altTestParameters.Remove('CertificateThumbPrint')

                    $setTargetPaths = @{
                        DatabasePath        = 'TestDrive:\Database'
                        ConfigurationPath   = 'TestDrive:\Configuration'
                        ModulePath          = 'TestDrive:\Module'
                        RegistrationKeyPath = 'TestDrive:\RegistrationKey'
                    }

                    It 'Should call expected mocks' {
                        Mock -CommandName Get-Website -MockWith {
                            [PSCustomObject]@{
                                Name = $Name
                                State = 'Stopped'
                                applicationPool = 'PSWS'
                                physicalPath = 'TestDrive:\inetpub\PesterTestSite'
                            }
                        } -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Set-TargetResource @altTestParameters @setTargetPaths -Ensure Present -CertificateSubject 'PesterTestCertificate'

                        Assert-MockCalled -Exactly -Times 1 -CommandName Find-CertificateThumbprintWithSubjectAndTemplateName
                    }
                }

                Context -Name 'When Ensure is Present and CertificateThumbprint and UseSecurityBestPractices is $true' -Fixture {
                    Mock -CommandName Set-UseSecurityBestPractice

                    $altTestParameters = $script:testParameters.Clone()
                    $altTestParameters.UseSecurityBestPractices = $true
                    $altTestParameters.CertificateThumbPrint = $script:certificateData[0].Thumbprint

                    $setTargetPaths = @{
                        DatabasePath        = 'TestDrive:\Database'
                        ConfigurationPath   = 'TestDrive:\Configuration'
                        ModulePath          = 'TestDrive:\Module'
                        RegistrationKeyPath = 'TestDrive:\RegistrationKey'
                    }

                    It 'Should not throw an error' {
                        Mock -CommandName Get-Website -MockWith {
                            [PSCustomObject]@{
                                Name = $Name
                                State = 'Stopped'
                                applicationPool = 'PSWS'
                                physicalPath = 'TestDrive:\inetpub\PesterTestSite'
                            }
                        } -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        {
                            Set-TargetResource @altTestParameters @setTargetPaths -Ensure Present
                        } | Should -Not -throw
                    }

                    It 'Should call expected mocks' {
                        Assert-MockCalled -Exactly -Times 0 -CommandName Find-CertificateThumbprintWithSubjectAndTemplateName
                        Assert-MockCalled -Exactly -Times 1 -CommandName Set-UseSecurityBestPractice
                    }
                }

                Context -Name 'When function parameters contain invalid data' -Fixture {
                    It 'Should throw if CertificateThumbprint and CertificateSubject are not specifed' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Remove('CertificateThumbPrint')

                        {
                            Set-TargetResource @altTestParameters
                        } | Should -Throw
                    }
                }

                Context -Name 'When firewall rules need to be validated' -Fixture {
                    $setTargetPaths = @{
                        DatabasePath        = 'TestDrive:\Database'
                        ConfigurationPath   = 'TestDrive:\Configuration'
                        ModulePath          = 'TestDrive:\Module'
                        RegistrationKeyPath = 'TestDrive:\RegistrationKey'
                    }

                    Mock -CommandName Remove-PSWSEndpoint

                    It 'Should not create any firewall rules if disabled' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Ensure = 'Present'
                        $altTestParameters.ConfigureFirewall = $false

                        Mock -CommandName Add-PullServerFirewallConfiguration
                        Mock -CommandName Get-Website -MockWith { $null } -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Set-TargetResource @altTestParameters @setTargetPaths

                        Assert-MockCalled -Exactly -Times 0 -CommandName Add-PullServerFirewallConfiguration
                    }

                    It 'Should create firewall rules when enabled' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Ensure = 'Present'
                        $altTestParameters.ConfigureFirewall = $true

                        Mock -CommandName Add-PullServerFirewallConfiguration
                        Mock -CommandName Get-Website -MockWith { $null } -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Set-TargetResource @altTestParameters @setTargetPaths
                        Assert-MockCalled -Exactly -Times 1 -CommandName Add-PullServerFirewallConfiguration
                    }

                    It 'Should always delete firewall rules which match the display internal name and port' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Ensure = 'Absent'
                        $altTestParameters.ConfigureFirewall = $true

                        Mock -CommandName Get-Website -MockWith {
                            [PSCustomObject]@{
                                Name = $Name
                                State = 'Stopped'
                                applicationPool = 'PSWS'
                                physicalPath = 'TestDrive:\inetpub\PesterTestSite'
                            }
                        } -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Mock -CommandName Get-WebBinding -MockWith {
                            [PSCustomObject]@{
                                protocol = 'http'
                                bindingInformation = '*:8080:'
                            }
                            [PSCustomObject]@{
                                protocol = 'http'
                                bindingInformation = '*:8090:'
                            }
                            [PSCustomObject]@{
                                protocol = 'http'
                                bindingInformation = 'http://test.local/DSCPullServer:8010:'
                            }
                        }
                        Mock -CommandName Test-PullServerFirewallConfiguration `
                            -MockWith { $true } `
                            -ModuleName xPSDesiredStateConfiguration.Firewall
                        Mock -CommandName Get-Command `
                            -ParameterFilter {
                                $Name -eq 'Get-NetFirewallRule'
                            } `
                            -MockWith { $true } `
                            -ModuleName xPSDesiredStateConfiguration.Firewall
                        Mock -CommandName Get-NetFirewallRule -MockWith {
                            if ($DisplayName -notlike 'DSCPullServer_IIS_Port*')
                            {
                                throw "Invalid DisplayName filter [$DisplayName] for Get-NetFirewallRule"
                            }
                        } -ModuleName xPSDesiredStateConfiguration.Firewall

                        Set-TargetResource @altTestParameters @setTargetPaths

                        Assert-MockCalled -Exactly -Times 3 -CommandName Test-PullServerFirewallConfiguration -ModuleName xPSDesiredStateConfiguration.Firewall
                        Assert-MockCalled -Exactly -Times 3 -CommandName Get-NetFirewallRule -ModuleName xPSDesiredStateConfiguration.Firewall
                    }
                }

                Context -Name 'When application pool needs to be validated' -Fixture {
                    $setTargetPaths = @{
                        DatabasePath        = 'TestDrive:\Database'
                        ConfigurationPath   = 'TestDrive:\Configuration'
                        ModulePath          = 'TestDrive:\Module'
                        RegistrationKeyPath = 'TestDrive:\RegistrationKey'
                    }

                    It 'Ensure is Absent - An AppPool still bound by an application should not be deleted' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Ensure = 'Absent'

                        Mock -CommandName Get-Website -MockWith {
                            [PSCustomObject]@{
                                Name = $Name
                                State = 'Stopped'
                                applicationPool = 'PSWS'
                                physicalPath = 'TestDrive:\inetpub\PesterTestSite'
                            }
                        } -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Mock -CommandName Get-ChildItem `
                            -ParameterFilter {
                                $Path -eq 'TestDrive:\inetpub\PesterTestSite'
                            } `
                            -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Mock -CommandName Get-AppPoolBinding `
                            -MockWith {
                                'Default Web Site'
                            } `
                            -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Set-TargetResource @altTestParameters @setTargetPaths

                        Assert-MockCalled -Exactly -Times 0 -CommandName Remove-WebAppPool -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                    }

                    It 'Ensure is Present - No standard AppPool that does not exist should throw' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Ensure = 'Present'
                        $altTestParameters.ApplicationPoolName = 'NonExistingAppPool'

                        Mock -CommandName Test-Path -ParameterFilter {
                            $Path -eq 'IIS:\AppPools\NonExistingAppPool'
                        } -MockWith {
                            $false
                        }

                        {
                            Set-TargetResource @altTestParameters @setTargetPaths
                        } | Should -Throw

                        Assert-MockCalled -Exactly -Times 1 -CommandName Test-Path -Scope It
                    }

                    It 'Ensure is Present - No standard AppPool will be created if an external AppPool is specified' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Ensure = 'Present'
                        $altTestParameters.ApplicationPoolName = 'PullServer AppPool'

                        Mock -CommandName Test-Path -ParameterFilter {
                            $Path -eq 'IIS:\AppPools\PullServer AppPool'
                        } -MockWith {
                            $true
                        }
                        Mock -CommandName New-WebAppPool -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Set-TargetResource @altTestParameters @setTargetPaths

                        Assert-MockCalled -Exactly -Times 0 -CommandName New-WebAppPool -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                    }

                    It 'Ensure is Absent - An externally defined AppPool should not be deleted' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Ensure = 'Absent'
                        $altTestParameters.ApplicationPoolName = 'PullServer AppPool'

                        Mock -CommandName Get-Website -MockWith {
                            [PSCustomObject]@{
                                Name = $Name
                                State = 'Stopped'
                                applicationPool = 'PullServer AppPool'
                                physicalPath = 'TestDrive:\inetpub\PesterTestSite'
                            }
                        } -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                        Mock -CommandName Test-Path -ParameterFilter {
                                $Path -eq 'IIS:\AppPools\PullServer AppPool'
                            } -MockWith { $true } `
                            -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                        Mock -CommandName Get-AppPoolBinding `
                            -MockWith { $null } `
                            -ModuleName xPSDesiredStateConfiguration.PSWSIIS
                        Mock -CommandName Remove-WebAppPool -ModuleName xPSDesiredStateConfiguration.PSWSIIS

                        Set-TargetResource @altTestParameters @setTargetPaths

                        Assert-MockCalled -Exactly -Times 0 -CommandName Test-Path -ModuleName xPSDesiredStateConfiguration.PSWSIIS -ParameterFilter { $Path -eq 'IIS:\AppPools\PullServer AppPool' } -Scope It
                        Assert-MockCalled -Exactly -Times 0 -CommandName Get-AppPoolBinding -ModuleName xPSDesiredStateConfiguration.PSWSIIS -Scope It
                        Assert-MockCalled -Exactly -Times 0 -CommandName Remove-WebAppPool -ModuleName xPSDesiredStateConfiguration.PSWSIIS -Scope It
                    }
                }
            }

            Describe -Name 'DSC_xDSCWebService\Test-TargetResource' -Fixture {
                function Get-Website {}
                function Get-WebBinding {}
                function Stop-Website {}

                #region Mocks
                Mock -CommandName Get-Command -ParameterFilter {$Name -eq '.\appcmd.exe'} -MockWith {
                    {
                        $allowedArgs = @(
                            '('''' -ne ((& (Get-IISAppCmd) list config -section:system.webServer/globalModules) -like "*$iisSelfSignedModuleName*"))'
                        )

                        $line = $MyInvocation.Line.Trim() -replace '\s+', ' '

                        if ($allowedArgs -notcontains $line)
                        {
                            throw "Mock test failed. Invalid parameters [$line]"
                        }
                    }
                }
                #endregion

                Context -Name 'When DSC Service is not installed' -Fixture {
                    It 'Should return $true when Ensure is Absent' {
                        Test-TargetResource @script:testParameters -Ensure Absent | Should -BeTrue
                    }

                    It 'Should return $false when Ensure is Present' {
                        Test-TargetResource @script:testParameters -Ensure Present | Should -BeFalse
                    }
                }

                Context -Name 'When DSC Web Service is installed as HTTP' -Fixture {
                    Mock -CommandName Get-Website -MockWith {
                        $script:websiteDataHTTP
                    }
                    Mock -CommandName Test-PullServerFirewallConfiguration -MockWith { $false }

                    It 'Should return $false when Ensure is Absent' {
                        Test-TargetResource @script:testParameters -Ensure Absent | Should -BeFalse
                    }

                    It 'Should return $false if Port doesn''t match' {
                        Test-TargetResource @script:testParameters -Ensure Present -Port 8081 | Should -BeFalse
                    }

                    It 'Should return $false if Certificate Thumbprint is set' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.CertificateThumbprint = $script:certificateData[0].Thumbprint
                        Test-TargetResource @altTestParameters -Ensure Present | Should -BeFalse
                    }

                    It 'Should return $false if Physical Path doesn''t match' {
                        Mock -CommandName Test-WebsitePath -MockWith { $true } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present | Should -BeFalse

                        Assert-VerifiableMock
                    }

                    Mock -CommandName Get-WebBinding -MockWith {
                        return @{
                            CertificateHash = $script:websiteDataHTTPS.bindings.collection[0].certificateHash
                        }
                    }
                    Mock -CommandName Test-WebsitePath -MockWith { $false } -Verifiable

                    It 'Should return $false when State is set to Stopped' {
                        Test-TargetResource @script:testParameters -Ensure Present -State Stopped | Should -BeFalse

                        Assert-VerifiableMock
                    }

                    It 'Should return $false when dbProvider is not set' {
                        Mock -CommandName Get-WebConfigAppSetting -MockWith {''} -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present | Should -BeFalse

                        Assert-VerifiableMock
                    }

                    Mock -CommandName Test-WebConfigAppSetting -MockWith {Write-Verbose -Message 'Test-WebConfigAppSetting'; $true}

                    It 'Should return $true when dbProvider is set to ESENT and ConnectionString does not match the value in web.config' {
                        $DatabasePath = 'TestDrive:\DatabasePath'

                        Mock -CommandName Get-WebConfigAppSetting -MockWith {'ESENT'} -Verifiable
                        Mock -CommandName Test-WebConfigAppSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - dbconnectionstr (ESENT)'
                            ('{0}\Devices.edb' -f $DatabasePath) -eq $ExpectedAppSettingValue
                        } -ParameterFilter {
                            $AppSettingName -eq 'dbconnectionstr'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present -DatabasePath $DatabasePath  | Should -BeTrue

                        Assert-VerifiableMock
                    }

                    It 'Should return $false when dbProvider is set to ESENT and ConnectionString does match the value in web.config' {
                        Mock -CommandName Get-WebConfigAppSetting -MockWith {'ESENT'} -Verifiable
                        Mock -CommandName Test-WebConfigAppSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - dbconnectionstr (ESENT)'
                            $false
                        } -ParameterFilter {
                            $AppSettingName -eq 'dbconnectionstr'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present | Should -BeFalse

                        Assert-VerifiableMock
                    }

                    It 'Should return $true when dbProvider is set to System.Data.OleDb and ConnectionString does not match the value in web.config' {
                        $DatabasePath = 'TestDrive:\DatabasePath'

                        Mock -CommandName Get-WebConfigAppSetting -MockWith {'System.Data.OleDb'} -Verifiable
                        Mock -CommandName Test-WebConfigAppSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - dbconnectionstr (OLE)'
                            ('Provider=Microsoft.Jet.OLEDB.4.0;Data Source={0}\Devices.mdb;' -f $DatabasePath) -eq $ExpectedAppSettingValue
                        } -ParameterFilter {
                            $AppSettingName -eq 'dbconnectionstr'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present -DatabasePath $DatabasePath | Should -BeTrue

                        Assert-VerifiableMock
                    }

                    It 'Should return $false when dbProvider is set to System.Data.OleDb and ConnectionString does match the value in web.config' {
                        Mock -CommandName Get-WebConfigAppSetting -MockWith { 'System.Data.OleDb' } -Verifiable
                        Mock -CommandName Test-WebConfigAppSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - dbconnectionstr (OLE)'
                            $false} -ParameterFilter {$AppSettingName -eq 'dbconnectionstr'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present | Should -BeFalse

                        Assert-VerifiableMock
                    }

                    Mock -CommandName Get-WebConfigAppSetting -MockWith { 'ESENT' } -Verifiable
                    Mock -CommandName Test-WebConfigAppSetting -MockWith { $true } -ParameterFilter {
                        $AppSettingName -eq 'dbconnectionstr'
                    } -Verifiable

                    It 'Should return $true when ModulePath is set the same as in web.config' {
                        $modulePath = 'TestDrive:\ModulePath'

                        Mock -CommandName Test-WebConfigAppSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - ModulePath'
                            $modulePath -eq $ExpectedAppSettingValue
                        } -ParameterFilter {
                            $AppSettingName -eq 'ModulePath'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present -ModulePath $modulePath | Should -BeTrue

                        Assert-VerifiableMock
                    }

                    It 'Should return $false when ModulePath is not set the same as in web.config' {
                        Mock -CommandName Test-WebConfigAppSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - ModulePath'
                            $false
                        } -ParameterFilter {
                            $AppSettingName -eq 'ModulePath'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present | Should -BeFalse

                        Assert-VerifiableMock
                    }

                    Mock -CommandName Test-WebConfigAppSetting -MockWith { $true } -ParameterFilter {
                        $AppSettingName -eq 'ModulePath'
                    } -Verifiable

                    It 'Should return $true when ConfigurationPath is set the same as in web.config' {
                        $configurationPath = 'TestDrive:\ConfigurationPath'

                        Mock -CommandName Test-WebConfigAppSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - ConfigurationPath'
                            $configurationPath -eq $ExpectedAppSettingValue
                        } -ParameterFilter {
                            $AppSettingName -eq 'ConfigurationPath'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present -ConfigurationPath $configurationPath | Should -BeTrue

                        Assert-VerifiableMock
                    }

                    It 'Should return $false when ConfigurationPath is not set the same as in web.config' {
                        $configurationPath = 'TestDrive:\ConfigurationPath'

                        Mock -CommandName Test-WebConfigAppSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - ConfigurationPath'
                            $false
                        } -ParameterFilter {
                            $AppSettingName -eq 'ConfigurationPath'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present -ConfigurationPath $configurationPath | Should -BeFalse

                        Assert-VerifiableMock
                    }

                    Mock -CommandName Test-WebConfigAppSetting -MockWith { $true } -ParameterFilter {
                        $AppSettingName -eq 'ConfigurationPath'
                    } -Verifiable

                    It 'Should return $true when RegistrationKeyPath is set the same as in web.config' {
                        $registrationKeyPath = 'TestDrive:\RegistrationKeyPath'

                        Mock -CommandName Test-WebConfigAppSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - RegistrationKeyPath'
                            $registrationKeyPath -eq $ExpectedAppSettingValue
                        } -ParameterFilter {
                            $AppSettingName -eq 'RegistrationKeyPath'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present -RegistrationKeyPath $registrationKeyPath | Should -BeTrue

                        Assert-VerifiableMock
                    }

                    It 'Should return $false when RegistrationKeyPath is not set the same as in web.config' {
                        $registrationKeyPath = 'TestDrive:\RegistrationKeyPath'

                        Mock -CommandName Test-WebConfigAppSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - RegistrationKeyPath'
                            $false
                        } -ParameterFilter {
                            $AppSettingName -eq 'RegistrationKeyPath'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present -RegistrationKeyPath $registrationKeyPath | Should -BeFalse

                        Assert-VerifiableMock
                    }

                    It 'Should return $true when AcceptSelfSignedCertificates is set the same as in web.config' {
                        $acceptSelfSignedCertificates = $true

                        Mock -CommandName Test-IISSelfSignedModuleInstalled -MockWith { $true }
                        Mock -CommandName Test-WebConfigModulesSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - IISSelfSignedCertModule'
                            $acceptSelfSignedCertificates -eq $ExpectedInstallationStatus
                        } -ParameterFilter {
                            $ModuleName -eq 'IISSelfSignedCertModule(32bit)'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present -AcceptSelfSignedCertificates $acceptSelfSignedCertificates | Should -BeTrue

                        Assert-VerifiableMock
                    }

                    It 'Should return $false when AcceptSelfSignedCertificates is not set the same as in web.config' {
                        $acceptSelfSignedCertificates = $true

                        Mock -CommandName Test-IISSelfSignedModuleInstalled -MockWith { $true }
                        Mock -CommandName Test-WebConfigModulesSetting -MockWith {
                            Write-Verbose -Message 'Test-WebConfigAppSetting - IISSelfSignedCertModule'
                            $false
                        } -ParameterFilter {
                            $ModuleName -eq 'IISSelfSignedCertModule(32bit)'
                        } -Verifiable

                        Test-TargetResource @script:testParameters -Ensure Present -AcceptSelfSignedCertificates $acceptSelfSignedCertificates | Should -BeFalse

                        Assert-VerifiableMock
                    }
                }

                Context -Name 'When DSC Web Service is installed as HTTPS' -Fixture {
                    Mock -CommandName Get-Website -MockWith { $script:websiteDataHTTPS }
                    Mock -CommandName Test-PullServerFirewallConfiguration -MockWith { $false }

                    It 'Should return $false if Certificate Thumbprint is set to AllowUnencryptedTraffic' {
                        Test-TargetResource @script:testParameters -Ensure Present | Should -BeFalse
                    }

                    It 'Should return $false if Certificate Subject does not match the current certificate' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Remove('CertificateThumbprint')

                        Mock -CommandName Find-CertificateThumbprintWithSubjectAndTemplateName -MockWith {'ZZYYXXWWVVUUTTSSRRQQPPOONNMMLLKKJJIIHHGG'}

                        Test-TargetResource @altTestParameters -Ensure Present -CertificateSubject 'Invalid Certifcate' | Should -BeFalse
                    }

                    Mock -CommandName Test-WebsitePath -MockWith { $false } -Verifiable

                    It 'Should return $false when UseSecurityBestPractices and insecure protocols are enabled' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.UseSecurityBestPractices = $true
                        $altTestParameters.CertificateThumbprint    = $script:certificateData[0].Thumbprint

                        Mock -CommandName Get-WebConfigAppSetting -MockWith { 'ESENT' } -Verifiable
                        Mock -CommandName Test-WebConfigAppSetting -MockWith { $true } -ParameterFilter {
                            $AppSettingName -eq 'dbconnectionstr'
                        } -Verifiable
                        Mock -CommandName Test-WebConfigAppSetting -MockWith { $true } -ParameterFilter {
                            $AppSettingName -eq 'ModulePath'
                        } -Verifiable
                        Mock -CommandName Test-UseSecurityBestPractice -MockWith { $false } -Verifiable

                        Test-TargetResource @altTestParameters -Ensure Present | Should -BeFalse

                        Assert-VerifiableMock
                    }
                }

                Context -Name 'When function parameters contain invalid data' -Fixture {
                    It 'Should throw if CertificateThumbprint and CertificateSubject are not specifed' {
                        $altTestParameters = $script:testParameters.Clone()
                        $altTestParameters.Remove('CertificateThumbPrint')

                        {Test-TargetResource @altTestParameters} | Should -Throw
                    }
                }
            }

            Describe -Name 'DSC_xDSCWebService\Test-WebsitePath' -Fixture {
                function Get-Website {}
                function Get-WebBinding {}
                function Stop-Website {}

                $endpointPhysicalPath = 'TestDrive:\SitePath1'
                Mock -CommandName Get-ItemProperty -MockWith {$endpointPhysicalPath}

                It 'Should return $true if Endpoint PhysicalPath doesn''t match PhysicalPath' {
                    Test-WebsitePath -EndpointName 'PesterSite' -PhysicalPath 'TestDrive:\SitePath2' | Should -BeTrue

                    Assert-VerifiableMock
                }

                It 'Should return $true if Endpoint PhysicalPath doesn''t match PhysicalPath' {
                    Test-WebsitePath -EndpointName 'PesterSite' -PhysicalPath $endpointPhysicalPath | Should -BeFalse

                    Assert-VerifiableMock
                }
            }

            Describe -Name 'DSC_xDSCWebService\Test-WebConfigAppSetting' -Fixture {
                function Get-Website {}
                function Get-WebBinding {}
                function Stop-Website {}

                $script:webConfigPath = 'TestDrive:\Web.config'
                $null = New-Item -Path $script:webConfigPath -Value $script:webConfig

                $testCases = @(
                    @{
                        Key   = 'dbprovider'
                        Value = 'ESENT'
                    }
                    @{
                        Key   = 'dbconnectionstr'
                        Value = 'TestDrive:\DatabasePath\Devices.edb'
                    }
                    @{
                        Key   = 'ModulePath'
                        Value = 'TestDrive:\ModulePath'
                    }
                )

                It 'Should return $true when ExpectedAppSettingValue is <Value> for <Key>.' -TestCases $testCases {
                    param
                    (
                        [Parameter(Mandatory = $true)]
                        [System.String]
                        $Key,

                        [Parameter(Mandatory = $true)]
                        [System.String]
                        $Value
                    )
                    Test-WebConfigAppSetting -WebConfigFullPath $script:webConfigPath -AppSettingName $Key -ExpectedAppSettingValue $Value | Should -BeTrue
                }

                It 'Should return $false when ExpectedAppSettingValue is not <Value> for <Key>.' -TestCases $testCases {
                    param
                    (
                        [Parameter(Mandatory = $true)]
                        [System.String]
                        $Key,

                        [Parameter(Mandatory = $true)]
                        [System.String]
                        $Value
                    )
                    Test-WebConfigAppSetting -WebConfigFullPath $script:webConfigPath -AppSettingName $Key -ExpectedAppSettingValue 'InvalidValue' | Should -BeFalse
                }
            }

            Describe -Name 'DSC_xDSCWebService\Get-WebConfigAppSetting' -Fixture {
                function Get-Website {}
                function Get-WebBinding {}
                function Stop-Website {}

                $script:webConfigPath = 'TestDrive:\Web.config'
                $null = New-Item -Path $script:webConfigPath -Value $script:webConfig

                $testCases = @(
                    @{
                        Key   = 'dbprovider'
                        Value = 'ESENT'
                    }
                    @{
                        Key   = 'dbconnectionstr'
                        Value = 'TestDrive:\DatabasePath\Devices.edb'
                    }
                    @{
                        Key   = 'ModulePath'
                        Value = 'TestDrive:\ModulePath'
                    }
                )

                It 'Should return <Value> when Key is <Key>.' -TestCases $testCases {
                    param
                    (
                        [Parameter(Mandatory = $true)]
                        [System.String]
                        $Key,

                        [Parameter(Mandatory = $true)]
                        [System.String]
                        $Value
                    )
                    Get-WebConfigAppSetting -WebConfigFullPath $script:webConfigPath -AppSettingName $Key | Should -Be $Value
                }

                It 'Should return Null if Key is not found' {
                    Get-WebConfigAppSetting -WebConfigFullPath $script:webConfigPath -AppSettingName 'InvalidKey' | Should -BeNullOrEmpty
                }
            }

            Describe -Name 'DSC_xDSCWebService\Test-WebConfigModulesSetting' -Fixture {

                function Get-Website {}
                function Get-WebBinding {}
                function Stop-Website {}

                $script:webConfigPath = 'TestDrive:\Web.config'
                $null = New-Item -Path $script:webConfigPath -Value $script:webConfig

                It 'Should return $true if Module is present in Web.config and expected to be installed.' {
                    Test-WebConfigModulesSetting -WebConfigFullPath $script:webConfigPath -ModuleName 'IISSelfSignedCertModule(32bit)' -ExpectedInstallationStatus $true | Should -BeTrue
                }

                It 'Should return $false if Module is present in Web.config and not expected to be installed.' {
                    Test-WebConfigModulesSetting -WebConfigFullPath $script:webConfigPath -ModuleName 'IISSelfSignedCertModule(32bit)' -ExpectedInstallationStatus $false | Should -BeFalse
                }

                It 'Should return $true if Module is not present in Web.config and not expected to be installed.' {
                    Test-WebConfigModulesSetting -WebConfigFullPath $script:webConfigPath -ModuleName 'FakeModule' -ExpectedInstallationStatus $false | Should -BeTrue
                }

                It 'Should return $false if Module is not present in Web.config and expected to be installed.' {
                    Test-WebConfigModulesSetting -WebConfigFullPath $script:webConfigPath -ModuleName 'FakeModule' -ExpectedInstallationStatus $true | Should -BeFalse
                }
            }

            Describe -Name 'DSC_xDSCWebService\Get-WebConfigModulesSetting' -Fixture {
                function Get-Website {}
                function Get-WebBinding {}
                function Stop-Website {}

                $script:webConfigPath = 'TestDrive:\Web.config'
                $null = New-Item -Path $script:webConfigPath -Value $script:webConfig

                It 'Should return the Module name if it is present in Web.config.' {
                    Get-WebConfigModulesSetting -WebConfigFullPath $script:webConfigPath -ModuleName 'IISSelfSignedCertModule(32bit)' | Should -Be 'IISSelfSignedCertModule(32bit)'
                }

                It 'Should return an empty string if the module is not present in Web.config.' {
                    Get-WebConfigModulesSetting -WebConfigFullPath $script:webConfigPath -ModuleName 'FakeModule' | Should -Be ''
                }
            }

            Describe -Name 'DSC_xDSCWebService\Update-LocationTagInApplicationHostConfigForAuthentication' -Fixture {
                function Get-Website {}
                function Get-WebBinding {}
                function Stop-Website {}

                $appHostConfigSection = [System.Management.Automation.PSObject] @{
                    OverrideMode = ''
                }

                $appHostConfig        = [System.Management.Automation.PSObject] @{}
                $webAdminSrvMgr       = [System.Management.Automation.PSObject] @{}

                Add-Member -InputObject $appHostConfig  -MemberType ScriptMethod -Name GetSection -Value {$appHostConfigSection}
                Add-Member -InputObject $webAdminSrvMgr -MemberType ScriptMethod -Name GetApplicationHostConfiguration -Value {$appHostConfig}
                Add-Member -InputObject $webAdminSrvMgr -MemberType ScriptMethod -Name CommitChanges -Value {}

                Mock -CommandName Get-IISServerManager -MockWith {
                    $webAdminSrvMgr
                } -Verifiable

                Update-LocationTagInApplicationHostConfigForAuthentication -Website 'PesterSite' -Authentication 'Basic'

                It 'Should call expected mocks' {
                    Assert-VerifiableMock
                    Assert-MockCalled Get-IISServerManager -Exactly 1
                }
            }

            Describe -Name 'DSC_xDSCWebService\Find-CertificateThumbprintWithSubjectAndTemplateName' -Fixture {
                function Get-Website {}
                function Get-WebBinding {}
                function Stop-Website {}


                Mock -CommandName Get-ChildItem -MockWith {
                    ,@($script:certificateData)
                }

                It 'Should return the certificate thumbprint when the certificate is found' {
                    Find-CertificateThumbprintWithSubjectAndTemplateName -Subject $script:certificateData[0].Subject -TemplateName 'WebServer' |
                        Should -Be $script:certificateData[0].Thumbprint
                }

                It 'Should throw an error when the certificate is not found' {
                    $subject      = $script:certificateData[0].Subject
                    $templateName = 'Invalid Template Name'

                    $errorMessage = ($script:localizedData.FindCertificateBySubjectNotFound -f $subject, $templateName)
                    {
                        Find-CertificateThumbprintWithSubjectAndTemplateName -Subject $subject -TemplateName $templateName
                    } | Should -Throw -ExpectedMessage $errorMessage
                }

                It 'Should throw an error when the more than one certificate is found' {
                    $subject      = $script:certificateData[1].Subject
                    $templateName = 'WebServer'

                    $errorMessage = ($script:localizedData.FindCertificateBySubjectMultiple -f $subject, $templateName)
                    {
                        Find-CertificateThumbprintWithSubjectAndTemplateName -Subject $subject -TemplateName $templateName
                    } | Should -Throw -ExpectedMessage $errorMessage
                }
            }

            Describe -Name 'DSC_xDSCWebService\Get-OsVersion' -Fixture {
                It 'Should return a System.Version object' {
                    Get-OsVersion | Should -BeOfType System.Version
                }
            }

            Describe -Name 'DSC_xDSCWebService\Test-OsVersionBlue' -Fixture {
                It 'Should return true if version is 7.0.0.0' {
                    Mock -CommandName Get-OsVersion -MockWith { [System.Version] '7.0.0.0' }
                    Test-OsVersionBlue | Should -BeFalse
                }

                It 'Should return true if version is 6.3.0.0' {
                    Mock -CommandName Get-OsVersion -MockWith { [System.Version] '6.3.0.0' }
                    Test-OsVersionBlue | Should -BeTrue
                }

                It 'Should return true if version is 6.2.0.0' {
                    Mock -CommandName Get-OsVersion -MockWith { [System.Version] '6.2.0.0' }
                    Test-OsVersionBlue | Should -BeFalse
                }
            }

            Describe -Name 'DSC_xDSCWebService\Test-OsVersionDownLevelOfBlue' -Fixture {
                It 'Should return true if version is 7.0.0.0' {
                    Mock -CommandName Get-OsVersion -MockWith { [System.Version] '7.0.0.0' }
                    Test-OsVersionDownLevelOfBlue | Should -BeFalse
                }

                It 'Should return true if version is 6.3.0.0' {
                    Mock -CommandName Get-OsVersion -MockWith { [System.Version] '6.3.0.0' }
                    Test-OsVersionDownLevelOfBlue | Should -BeFalse
                }

                It 'Should return true if version is 6.2.0.0' {
                    Mock -CommandName Get-OsVersion -MockWith { [System.Version] '6.2.0.0' }
                    Test-OsVersionDownLevelOfBlue | Should -BeTrue
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
