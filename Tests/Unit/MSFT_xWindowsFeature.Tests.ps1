# These tests use a mock server module. They will fail on an actual server.
# All tests that require a credential will be skipped

Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonTestHelper.psm1') `
                               -Force

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

                    Assert-MockCalled -CommandName Invoke-Command -Times 1 -Scope It

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

                    Assert-MockCalled -CommandName Test-IsWinServer2008R2SP1 -Times 4 -Scope It
                }

                It 'Should return the correct hashtable when not all subfeatures are installed' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }
                    $mockWindowsFeatures[$testSubFeatureName3].Installed = $false

                    $result = Get-TargetResource -Name $testWindowsFeatureName1
                    $result.Name | Should Be $testWindowsFeatureName1
                    $result.DisplayName | Should Be $mockWindowsFeatures[$testWindowsFeatureName1].DisplayName
                    $result.Ensure | Should Be 'Absent'
                    $result.IncludeAllSubFeature | Should Be $false

                    Assert-MockCalled -CommandName Test-IsWinServer2008R2SP1 -Times 4 -Scope It

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
                    Assert-MockCalled -CommandName Add-WindowsFeature -Times 1 -Scope It
                }

                It 'Should call Remove-WindowsFeature when Ensure set to Absent' {
                    { Set-TargetResource -Name $testWindowsFeatureName2 -Ensure 'Absent' } | Should Not Throw
                    Assert-MockCalled -CommandName Remove-WindowsFeature -Times 1 -Scope It
                }

            }

            Context 'Install/Uninstall unsuccessful' {
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
                    Assert-MockCalled -CommandName Add-WindowsFeature -Times 1 -Scope It
                }

                It 'Should throw invalid operation exception when Ensure set to Absent' {
                    $errorId = 'FeatureUninstallationFailure'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                    $errorMessage = $($script:localizedData.FeatureUninstallationFailureError) -f $testWindowsFeatureName2 
                    $exception = New-Object System.InvalidOperationException $errorMessage 
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

                    { Set-TargetResource -Name $testWindowsFeatureName2 -Ensure 'Absent' } | Should Throw $errorRecord
                    Assert-MockCalled -CommandName Remove-WindowsFeature -Times 1 -Scope It
                }

            }
        }
    }
}
finally
{
    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
}
