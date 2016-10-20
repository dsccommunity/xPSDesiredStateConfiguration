# Needed to create a fake credential
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonTestHelper.psm1') `
                               -Force

# Need this module to import the localized data
Import-Module -Name (Join-Path -Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) `
              -ChildPath 'DSCResources\CommonResourceHelper.psm1')

# Localized messages for Write-Verbose statements
$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_xWindowsFeature'

$script:testEnvironment = Enter-DscResourceTestEnvironment `
    -DSCResourceModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xWindowsFeature' `
    -TestType Unit

try {
    InModuleScope 'MSFT_xWindowsFeature' {

        Import-Module -Name (Join-Path -Path $PSScriptRoot `
                                       -ChildPath (Join-Path -Path 'MockServerManager' `
                                                             -ChildPath 'MockServerManager.psm1')) `
                                       -Force

        $testUserName = 'TestUserName12345'
        $testUserPassword = 'StrongOne7.'
        $testSecurePassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
        $testCredential = New-Object PSCredential ($testUserName, $testSecurePassword)

        $testWindowsFeatureName1 = 'Test1'
        $testWindowsFeatureName2 = 'Test2'
        $testSubFeatureName1 = 'SubTest1'
        $testSubFeatureName2 = 'SubTest2'
        $testSubFeatureName3 = 'SubTest3'


        $mockWindowsFeatures = @{
            Test1 = @{ 
                Name                      = 'Test1'
                DisplayName               = 'Test Feature 1'
                Description               = 'Test Feature with 3 subfeatures'
                Installed                 = $false 
                InstallState              = 'Available' 
                FeatureType               = 'Role Service'
                Path                      = 'Test1'
                Depth                     = 1
                DependsOn                 = @()
                Parent                    = ''
                ServerComponentDescriptor = 'ServerComponent_Test_Cert_Authority'
                Subfeatures               = @('SubTest1','SubTest2','SubTest3')
                SystemService             = @()
                Notification              = @()
                BestPracticesModelId      = $null
                EventQuery                = $null
                PostConfigurationNeeded   = $false
                AdditionalInfo            = @('MajorVersion', 'MinorVersion', 'NumericId', 'InstallName')
            }

            SubTest1 = @{ 
                Name                      = 'SubTest1'
                DisplayName               = 'Sub Test Feature 1'
                Description               = 'Sub Test Feature with parent as test1'
                Installed                 = $true
                InstallState              = 'Available'
                FeatureType               = 'Role Service'
                Path                      = 'Test1\SubTest1'
                Depth                     = 2
                DependsOn                 = @()
                Parent                    = 'Test1'
                ServerComponentDescriptor = $null
                Subfeatures               = @()
                SystemService             = @()
                Notification              = @()
                BestPracticesModelId      = $null
                EventQuery                = $null
                PostConfigurationNeeded   = $false
                AdditionalInfo            = @('MajorVersion', 'MinorVersion', 'NumericId', 'InstallName')
            }

            SubTest2 = @{ 
                Name                      = 'SubTest2'
                DisplayName               = 'Sub Test Feature 2'
                Description               = 'Sub Test Feature with parent as test1'
                Installed                 = $true
                InstallState              = 'Available'
                FeatureType               = 'Role Service'
                Path                      = 'Test1\SubTest2'
                Depth                     = 2
                DependsOn                 = @()
                Parent                    = 'Test1'
                ServerComponentDescriptor = $null
                Subfeatures               = @()
                SystemService             = @()
                Notification              = @()
                BestPracticesModelId      = $null
                EventQuery                = $null
                PostConfigurationNeeded   = $false
                AdditionalInfo            = @('MajorVersion', 'MinorVersion', 'NumericId', 'InstallName')
            }

            SubTest3 = @{
                Name                      = 'SubTest3'
                DisplayName               = 'Sub Test Feature 3'
                Description               = 'Sub Test Feature with parent as test1'
                Installed                 = $true
                InstallState              = 'Available'
                FeatureType               = 'Role Service'
                Path                      = 'Test\SubTest3'
                Depth                     = 2
                DependsOn                 = @()
                Parent                    = 'Test1'
                ServerComponentDescriptor = $null
                Subfeatures               = @()
                SystemService             = @()
                Notification              = @()
                BestPracticesModelId      = $null
                EventQuery                = $null
                PostConfigurationNeeded   = $false
                AdditionalInfo            = @('MajorVersion', 'MinorVersion', 'NumericId', 'InstallName')
            }

            Test2 = @{ 
                Name                      = 'Test2'
                DisplayName               = 'Test Feature 2'
                Description               = 'Test Feature with 0 subfeatures'
                Installed                 = $true 
                InstallState              = 'Available' 
                FeatureType               = 'Role Service'
                Path                      = 'Test2'
                Depth                     = 1
                DependsOn                 = @()
                Parent                    = ''
                ServerComponentDescriptor = 'ServerComponent_Test_Cert_Authority'
                Subfeatures               = @()
                SystemService             = @()
                Notification              = @()
                BestPracticesModelId      = $null
                EventQuery                = $null
                PostConfigurationNeeded   = $false
                AdditionalInfo            = @('MajorVersion', 'MinorVersion', 'NumericId', 'InstallName')
            }
        }


        Describe 'xWindowsFeature/Get-TargetResource' {
            Mock -CommandName Assert-PrerequisitesValid -MockWith {}

            Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $testWindowsFeatureName2 } -MockWith {
                $windowsFeature = $mockWindowsFeatures[$testWindowsFeatureName2]
                $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                return $windowsFeatureObject
            }

            Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $testWindowsFeatureName1 } -MockWith {
                $windowsFeature = $mockWindowsFeatures[$testWindowsFeatureName1]
                $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                return $windowsFeatureObject
            }

            Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $testSubFeatureName1 } -MockWith {
                $windowsFeature = $mockWindowsFeatures[$testSubFeatureName1]
                $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                return $windowsFeatureObject
            }

            Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $testSubFeatureName2 } -MockWith {
                $windowsFeature = $mockWindowsFeatures[$testSubFeatureName2]
                $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                return $windowsFeatureObject
            }

            Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $testSubFeatureName3 } -MockWith {
                $windowsFeature = $mockWindowsFeatures[$testSubFeatureName3]
                $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                return $windowsFeatureObject
            }
            

            Context 'Windows Feature exists with no sub features' {
              
                It 'Should return the correct hashtable when not on a 2008 Server' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                    $result = Get-TargetResource -Name $testWindowsFeatureName2
                    $result.Name | Should Be $testWindowsFeatureName2
                    $result.DisplayName | Should Be $mockWindowsFeatures[$testWindowsFeatureName2].DisplayName
                    $result.Ensure | Should Be 'Present'
                    $result.IncludeAllSubFeature | Should Be $false
                }

                It 'Should return the correct hashtable when on a 2008 Server' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $true }

                    $result = Get-TargetResource -Name $testWindowsFeatureName2
                    $result.Name | Should Be $testWindowsFeatureName2
                    $result.DisplayName | Should Be $mockWindowsFeatures[$testWindowsFeatureName2].DisplayName
                    $result.Ensure | Should Be 'Present'
                    $result.IncludeAllSubFeature | Should Be $false
                }

                It 'Should return the correct hashtable when on a 2008 Server and Credential is passed' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $true }
                    Mock -CommandName Invoke-Command -MockWith { 
                        $windowsFeature = $mockWindowsFeatures[$testWindowsFeatureName2]
                        $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                        $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                        return $windowsFeatureObject
                    }

                    $result = Get-TargetResource -Name $testWindowsFeatureName2 -Credential $testCredential
                    $result.Name | Should Be $testWindowsFeatureName2
                    $result.DisplayName | Should Be $mockWindowsFeatures[$testWindowsFeatureName2].DisplayName
                    $result.Ensure | Should Be 'Present'
                    $result.IncludeAllSubFeature | Should Be $false

                    Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope It

                }
            }
            Context 'Windows Feature exists with sub features' {

                It 'Should return the correct hashtable when all subfeatures are installed' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                    $result = Get-TargetResource -Name $testWindowsFeatureName1
                    $result.Name | Should Be $testWindowsFeatureName1
                    $result.DisplayName | Should Be $mockWindowsFeatures[$testWindowsFeatureName1].DisplayName
                    $result.Ensure | Should Be 'Absent'
                    $result.IncludeAllSubFeature | Should Be $true

                    Assert-MockCalled -CommandName Test-IsWinServer2008R2SP1 -Times 4 -Exactly -Scope It
                }

                It 'Should return the correct hashtable when not all subfeatures are installed' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }
                    $mockWindowsFeatures[$testSubFeatureName3].Installed = $false

                    $result = Get-TargetResource -Name $testWindowsFeatureName1
                    $result.Name | Should Be $testWindowsFeatureName1
                    $result.DisplayName | Should Be $mockWindowsFeatures[$testWindowsFeatureName1].DisplayName
                    $result.Ensure | Should Be 'Absent'
                    $result.IncludeAllSubFeature | Should Be $false

                    Assert-MockCalled -CommandName Test-IsWinServer2008R2SP1 -Times 4 -Exactly -Scope It

                    $mockWindowsFeatures[$testSubFeatureName3].Installed = $true
                }
            }

            Context 'Windows Feature does not exist' {

                It 'Should throw invalid operation exception' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }
                    $badName = 'InvalidFeature'
                    $errorId = 'FeatureNotFound'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                    $errorMessage = $($script:localizedData.FeatureNotFoundError) -f $badName
                    $exception = New-Object System.InvalidOperationException $errorMessage
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

                    { Get-TargetResource -Name $badName } | Should Throw $errorRecord
                    
                }

            }
        }
        
        Describe 'xWindowsFeature/Set-TargetResource' {
            Mock -CommandName Assert-PrerequisitesValid -MockWith {}

            Context 'Install/Uninstall successful' {
                Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                Mock -CommandName Add-WindowsFeature -MockWith {
                    $windowsFeature = @{
                        Success = $true
                        RestartNeeded = 'No'
                        FeatureResult = @($testWindowsFeatureName2)
                        ExitCode = 'Success'
                    }
                    $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                    return $windowsFeatureObject
                }

                Mock -CommandName Remove-WindowsFeature -MockWith {
                    $windowsFeature = @{
                        Success = $true
                        RestartNeeded = 'No'
                        FeatureResult = @($testWindowsFeatureName2)
                        ExitCode = 'Success'
                    }
                    $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                    return $windowsFeatureObject
                }

                It 'Should call Add-WindowsFeature when Ensure set to Present' {
                    { Set-TargetResource -Name $testWindowsFeatureName2 -Ensure 'Present' } | Should Not Throw
                    Assert-MockCalled -CommandName Add-WindowsFeature -Times 1 -Exactly -Scope It
                }

                It 'Should call Remove-WindowsFeature when Ensure set to Absent' {
                    { Set-TargetResource -Name $testWindowsFeatureName2 -Ensure 'Absent' } | Should Not Throw
                    Assert-MockCalled -CommandName Remove-WindowsFeature -Times 1 -Exactly -Scope It
                }

            }

            Context 'Install/Uninstall unsuccessful' {
                Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                Mock -CommandName Add-WindowsFeature -MockWith {
                    $windowsFeature = @{
                        Success = $false
                        RestartNeeded = 'No'
                        FeatureResult = @($testWindowsFeatureName2)
                        ExitCode = 'Success'
                    }
                    $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                    return $windowsFeatureObject
                }

                Mock -CommandName Remove-WindowsFeature -MockWith {
                    $windowsFeature = @{
                        Success = $false
                        RestartNeeded = 'No'
                        FeatureResult = @($testWindowsFeatureName2)
                        ExitCode = 'Success'
                    }
                    $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                    return $windowsFeatureObject
                }

                It 'Should throw invalid operation exception when Ensure set to Present' {
                    $errorId = 'FeatureInstallationFailure'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                    $errorMessage = $($script:localizedData.FeatureInstallationFailureError) -f $testWindowsFeatureName2 
                    $exception = New-Object System.InvalidOperationException $errorMessage 
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

                    { Set-TargetResource -Name $testWindowsFeatureName2 -Ensure 'Present' } | Should Throw $errorRecord
                    Assert-MockCalled -CommandName Add-WindowsFeature -Times 1 -Exactly -Scope It
                }

                It 'Should throw invalid operation exception when Ensure set to Absent' {
                    $errorId = 'FeatureUninstallationFailure'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                    $errorMessage = $($script:localizedData.FeatureUninstallationFailureError) -f $testWindowsFeatureName2 
                    $exception = New-Object System.InvalidOperationException $errorMessage 
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

                    { Set-TargetResource -Name $testWindowsFeatureName2 -Ensure 'Absent' } | Should Throw $errorRecord
                    Assert-MockCalled -CommandName Remove-WindowsFeature -Times 1 -Exactly -Scope It
                }

            }

            Context 'Uninstall/Install with R2/SP1' {
                Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $true }

                Mock -CommandName Invoke-Command -MockWith {
                    $windowsFeature = @{
                        Success = $true
                        RestartNeeded = 'No'
                        FeatureResult = @($testWindowsFeatureName2)
                        ExitCode = 'Success'
                    }
                    $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                    return $windowsFeatureObject
                }

                It 'Should install the feature when Ensure set to Present and Credential and Source passed in' {

                    { 
                        Set-TargetResource -Name $testWindowsFeatureName2 `
                                           -Ensure 'Present' `
                                           -Source 'testSource' `
                                           -Credential $testCredential
                    } | Should Not Throw
                    Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope It
                    Assert-MockCalled -CommandName Add-WindowsFeature -Times 0 -Scope It
                }

                It 'Should uninstall the feature when Ensure set to Absent and Credential and Source passed in' {

                    { 
                        Set-TargetResource -Name $testWindowsFeatureName2 `
                                           -Ensure 'Absent' `
                                           -Source 'testSource' `
                                           -Credential $testCredential
                    } | Should Not Throw
                    Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope It
                    Assert-MockCalled -CommandName Remove-WindowsFeature -Times 0 -Scope It
                }
            }
        }

        Describe 'xWindowsFeature/Test-TargetResource' {
            Mock -CommandName Assert-PrerequisitesValid -MockWith {}

            Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $testWindowsFeatureName1 } -MockWith {
                $windowsFeature = $mockWindowsFeatures[$testWindowsFeatureName1]
                $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                return $windowsFeatureObject
            }

            Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $testSubFeatureName1 } -MockWith {
                $windowsFeature = $mockWindowsFeatures[$testSubFeatureName1]
                $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                return $windowsFeatureObject
            }

            Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $testSubFeatureName2 } -MockWith {
                $windowsFeature = $mockWindowsFeatures[$testSubFeatureName2]
                $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                return $windowsFeatureObject
            }

            Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $testSubFeatureName3 } -MockWith {
                $windowsFeature = $mockWindowsFeatures[$testSubFeatureName3]
                $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                return $windowsFeatureObject
            }

            # Used as Get-WindowsFeature when on R2/SP1 2008
            Mock -CommandName Invoke-Command -MockWith {
                $windowsFeature = $mockWindowsFeatures[$testWindowsFeatureName1]
                $windowsFeatureObject = New-Object PSObject -Property $windowsFeature
                $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'
            
                return $windowsFeatureObject
            }

            Context 'Feature is in the desired state' {

                It 'Should return true when Ensure set to Absent and Feature not installed' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Absent' `
                                                  -IncludeAllSubFeature $false
                    $result | Should Be $true
                    Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                }

                It 'Should return true when Ensure set to Present and Feature installed not checking subFeatures' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                    $mockWindowsFeatures[$testWindowsFeatureName1].Installed = $true
                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Present' `
                                                  -IncludeAllSubFeature $false
                    $result | Should Be $true
                    Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                    $mockWindowsFeatures[$testWindowsFeatureName1].Installed = $false
                }

                It 'Should return true when Ensure set to Present and Feature and subFeatures installed' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                    $mockWindowsFeatures[$testWindowsFeatureName1].Installed = $true
                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Present' `
                                                  -IncludeAllSubFeature $true
                    $result | Should Be $true
                    Assert-MockCalled -CommandName Get-WindowsFeature -Times 4 -Exactly -Scope It
                    $mockWindowsFeatures[$testWindowsFeatureName1].Installed = $false
                }

                It 'Should return true when Ensure set to Absent and Feature not installed and on R2/SP1 2008' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $true }

                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Absent' `
                                                  -Source 'testSource' `
                                                  -IncludeAllSubFeature $false `
                                                  -Credential $testCredential
                    $result | Should Be $true
                    Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope It
                }
            }

            Context 'Feature is not in the desired state' {
                Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                It 'Should return false when Ensure set to Present and Feature not installed' {
                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Present' `
                                                  -IncludeAllSubFeature $false
                    $result | Should Be $false
                    Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                }

                It 'Should return false when Ensure set to Absent and Feature installed not checking subFeatures' {
                    $mockWindowsFeatures[$testWindowsFeatureName1].Installed = $true
                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Absent' `
                                                  -IncludeAllSubFeature $false
                    $result | Should Be $false
                    Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                    $mockWindowsFeatures[$testWindowsFeatureName1].Installed = $false
                }

                It 'Should return false when Ensure set to Present, Feature not installed and subFeatures installed' {
                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Present' `
                                                  -IncludeAllSubFeature $true
                    $result | Should Be $false
                    Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                }

                It 'Should return false when Ensure set to Absent and Feature not installed but subFeatures installed' {
                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Absent' `
                                                  -IncludeAllSubFeature $true
                    $result | Should Be $false
                    Assert-MockCalled -CommandName Get-WindowsFeature -Times 2 -Exactly -Scope It
                }

                It 'Should return false when Ensure set to Absent and Feature installed and subFeatures installed' {
                    $mockWindowsFeatures[$testWindowsFeatureName1].Installed = $true
                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Absent' `
                                                  -IncludeAllSubFeature $true
                    $result | Should Be $false
                    Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                    $mockWindowsFeatures[$testWindowsFeatureName1].Installed = $false
                }

                It 'Should return false when Ensure set to Present and Feature installed but not all subFeatures installed' {
                    $mockWindowsFeatures[$testWindowsFeatureName1].Installed = $true
                    $mockWindowsFeatures[$testSubFeatureName2].Installed = $false
                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Present' `
                                                  -IncludeAllSubFeature $true
                    $result | Should Be $false
                    Assert-MockCalled -CommandName Get-WindowsFeature -Times 3 -Exactly -Scope It
                    $mockWindowsFeatures[$testWindowsFeatureName1].Installed = $false
                    $mockWindowsFeatures[$testSubFeatureName2].Installed = $true
                }

                It 'Should return false when Ensure set to Present and Feature not installed and on R2/SP1 2008' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $true }

                    $result = Test-TargetResource -Name $testWindowsFeatureName1 `
                                                  -Ensure 'Present' `
                                                  -Source 'testSource' `
                                                  -IncludeAllSubFeature $false `
                                                  -Credential $testCredential
                    $result | Should Be $false
                    Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope It
                }
            }
        }

        Describe 'xWindowsFeature/Assert-FeatureValid' { 
            $multipleFeature = @{
                Name = 'MultiFeatureName'
                Count = 2
            }

            It 'Should throw invalid operation when feature equals null' {
                $nonexistentName = 'NonexistentFeatureName'
                $errorId = 'FeatureNotFound'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                $errorMessage = $($script:localizedData.FeatureNotFoundError) -f $nonexistentName
                $exception = New-Object System.InvalidOperationException $errorMessage
                $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

                { Assert-FeatureValid -Name $nonexistentName } | Should Throw $errorRecord
            }

            It 'Should throw invalid operation when there are multiple features with the given name' {
                $errorId = 'FeatureDiscoveryFailure'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidResult
                $errorMessage = $($script:localizedData.FeatureDiscoveryFailureError) -f $multipleFeature.Name
                $exception = New-Object System.InvalidOperationException $errorMessage
                $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

                { Assert-FeatureValid -Feature $multipleFeature -Name $multipleFeature.Name } | Should Throw $errorRecord
            }
        }

        Describe 'xWindowsFeature/Assert-PrerequisitesValid' {
            $mockOperatingSystem = @{
                Name = 'mockOS'
                Version = '6.1.'
                OperatingSystemSKU = 10
            }
            Mock -CommandName Get-WmiObject -MockWith { return $mockOperatingSystem }

            It 'Should Not Throw' {
                Mock -CommandName Import-Module -MockWith {}
                { Assert-PrerequisitesValid } | Should Not Throw
            }

            It 'Should throw invalid operation exception' {
                Mock -CommandName Import-Module -MockWith { Throw }

                $errorId = 'SkuNotSupported'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                $errorMessage = $($script:localizedData.SkuNotSupported)
                $exception = New-Object System.InvalidOperationException $errorMessage
                $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

                { Assert-PrerequisitesValid } | Should Throw $errorRecord
            }

        }
    }
}
finally
{
    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
}
