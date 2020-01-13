# Needed to create a fake credential
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xWindowsFeature'

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
        Describe 'xWindowsFeature Unit Tests' {
            BeforeAll {
                function Add-WindowsFeature {
                    param (
                        [Parameter()]
                        [System.String]
                        $Name,

                        [Parameter()]
                        [Switch]
                        $IncludeAllSubFeature
                    )
                }

                function Get-WindowsFeature {
                    param (
                        [Parameter()]
                        [System.String]
                        $Name
                    )
                }

                function Remove-WindowsFeature {
                    param (
                        [Parameter()]
                        [System.String]
                        $Name
                    )
                }

                $script:testUserName = 'TestUserName12345'
                $script:testUserPassword = 'StrongOne7.'
                $script:testSecurePassword = ConvertTo-SecureString -String $script:testUserPassword -AsPlainText -Force
                $script:testCredential = New-Object -TypeName PSCredential -ArgumentList ($script:testUserName, $script:testSecurePassword)

                $script:testWindowsFeatureName1 = 'Test1'
                $script:testWindowsFeatureName2 = 'Test2'
                $script:testSubFeatureName1 = 'SubTest1'
                $script:testSubFeatureName2 = 'SubTest2'
                $script:testSubFeatureName3 = 'SubTest3'

                $script:mockWindowsFeatures = @{
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
                        Subfeatures               = @('SubTest1', 'SubTest2', 'SubTest3')
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
            }

            Describe 'xWindowsFeature/Get-TargetResource' {
                Mock -CommandName Import-ServerManager -MockWith {}

                Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $script:testWindowsFeatureName2 } -MockWith {
                    $windowsFeature = $script:mockWindowsFeatures[$script:testWindowsFeatureName2]
                    $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                    return $windowsFeatureObject
                }

                Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $script:testWindowsFeatureName1 } -MockWith {
                    $windowsFeature = $script:mockWindowsFeatures[$script:testWindowsFeatureName1]
                    $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                    return $windowsFeatureObject
                }

                Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $script:testSubFeatureName1 } -MockWith {
                    $windowsFeature = $script:mockWindowsFeatures[$script:testSubFeatureName1]
                    $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                    return $windowsFeatureObject
                }

                Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $script:testSubFeatureName2 } -MockWith {
                    $windowsFeature = $script:mockWindowsFeatures[$script:testSubFeatureName2]
                    $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                    return $windowsFeatureObject
                }

                Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $script:testSubFeatureName3 } -MockWith {
                    $windowsFeature = $script:mockWindowsFeatures[$script:testSubFeatureName3]
                    $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                    return $windowsFeatureObject
                }


                Context 'Windows Feature exists with no sub features' {
                    It 'Should return the correct hashtable when not on a 2008 Server' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                        $getTargetResourceResult = Get-TargetResource -Name $script:testWindowsFeatureName2
                        $getTargetResourceResult.Name | Should -Be $script:testWindowsFeatureName2
                        $getTargetResourceResult.DisplayName | Should -Be $script:mockWindowsFeatures[$script:testWindowsFeatureName2].DisplayName
                        $getTargetResourceResult.Ensure | Should -Be 'Present'
                        $getTargetResourceResult.IncludeAllSubFeature | Should -BeFalse
                    }

                    It 'Should return the correct hashtable when on a 2008 Server' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $true }

                        $getTargetResourceResult = Get-TargetResource -Name $script:testWindowsFeatureName2
                        $getTargetResourceResult.Name | Should -Be $script:testWindowsFeatureName2
                        $getTargetResourceResult.DisplayName | Should -Be $script:mockWindowsFeatures[$script:testWindowsFeatureName2].DisplayName
                        $getTargetResourceResult.Ensure | Should -Be 'Present'
                        $getTargetResourceResult.IncludeAllSubFeature | Should -BeFalse
                    }

                    It 'Should return the correct hashtable when on a 2008 Server and Credential is passed' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $true }
                        Mock -CommandName Invoke-Command -MockWith {
                            $windowsFeature = $script:mockWindowsFeatures[$script:testWindowsFeatureName2]
                            $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                            $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                            return $windowsFeatureObject
                        }

                        $getTargetResourceResult = Get-TargetResource -Name $script:testWindowsFeatureName2 -Credential $script:testCredential
                        $getTargetResourceResult.Name | Should -Be $script:testWindowsFeatureName2
                        $getTargetResourceResult.DisplayName | Should -Be $script:mockWindowsFeatures[$script:testWindowsFeatureName2].DisplayName
                        $getTargetResourceResult.Ensure | Should -Be 'Present'
                        $getTargetResourceResult.IncludeAllSubFeature | Should -BeFalse

                        Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope It

                    }
                }

                Context 'Windows Feature exists with sub features' {
                    It 'Should return the correct hashtable when all subfeatures are installed' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                        $getTargetResourceResult = Get-TargetResource -Name $script:testWindowsFeatureName1
                        $getTargetResourceResult.Name | Should -Be $script:testWindowsFeatureName1
                        $getTargetResourceResult.DisplayName | Should -Be $script:mockWindowsFeatures[$script:testWindowsFeatureName1].DisplayName
                        $getTargetResourceResult.Ensure | Should -Be 'Absent'
                        $getTargetResourceResult.IncludeAllSubFeature | Should -BeTrue

                        Assert-MockCalled -CommandName Test-IsWinServer2008R2SP1 -Times 1 -Exactly -Scope It
                    }

                    It 'Should return the correct hashtable when not all subfeatures are installed' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }
                        $script:mockWindowsFeatures[$script:testSubFeatureName3].Installed = $false

                        $getTargetResourceResult = Get-TargetResource -Name $script:testWindowsFeatureName1
                        $getTargetResourceResult.Name | Should -Be $script:testWindowsFeatureName1
                        $getTargetResourceResult.DisplayName | Should -Be $script:mockWindowsFeatures[$script:testWindowsFeatureName1].DisplayName
                        $getTargetResourceResult.Ensure | Should -Be 'Absent'
                        $getTargetResourceResult.IncludeAllSubFeature | Should -BeFalse

                        Assert-MockCalled -CommandName Test-IsWinServer2008R2SP1 -Times 1 -Exactly -Scope It

                        $script:mockWindowsFeatures[$script:testSubFeatureName3].Installed = $true
                    }
                }

                Context 'Windows Feature does not exist' {
                    It 'Should throw invalid operation exception' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }
                        $invalidName = 'InvalidFeature'
                        { Get-TargetResource -Name $invalidName } | Should -Throw ($script:localizedData.FeatureNotFoundError -f $invalidName)
                    }
                }
            }

            Describe 'xWindowsFeature/Set-TargetResource' {
                Mock -CommandName Import-ServerManager -MockWith {}

                Context 'Install/Uninstall successful' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                    Mock -CommandName Add-WindowsFeature -MockWith {
                        $windowsFeature = @{
                            Success = $true
                            RestartNeeded = 'No'
                            FeatureResult = @($script:testWindowsFeatureName2)
                            ExitCode = 'Success'
                        }
                        $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                        $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                        return $windowsFeatureObject
                    }

                    Mock -CommandName Remove-WindowsFeature -MockWith {
                        $windowsFeature = @{
                            Success = $true
                            RestartNeeded = 'No'
                            FeatureResult = @($script:testWindowsFeatureName2)
                            ExitCode = 'Success'
                        }
                        $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                        $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                        return $windowsFeatureObject
                    }

                    It 'Should call Add-WindowsFeature when Ensure set to Present' {
                        { Set-TargetResource -Name $script:testWindowsFeatureName2 -Ensure 'Present' } | Should -Not -Throw
                        Assert-MockCalled -CommandName Add-WindowsFeature -Times 1 -Exactly -Scope It
                    }

                    It 'Should call Remove-WindowsFeature when Ensure set to Absent' {
                        { Set-TargetResource -Name $script:testWindowsFeatureName2 -Ensure 'Absent' } | Should -Not -Throw
                        Assert-MockCalled -CommandName Remove-WindowsFeature -Times 1 -Exactly -Scope It
                    }
                }

                Context 'Install/Uninstall unsuccessful' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                    Mock -CommandName Add-WindowsFeature -MockWith {
                        $windowsFeature = @{
                            Success = $false
                            RestartNeeded = 'No'
                            FeatureResult = @($script:testWindowsFeatureName2)
                            ExitCode = 'Nothing succeeded'
                        }
                        $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                        $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                        return $windowsFeatureObject
                    }

                    Mock -CommandName Remove-WindowsFeature -MockWith {
                        $windowsFeature = @{
                            Success = $false
                            RestartNeeded = 'No'
                            FeatureResult = @($script:testWindowsFeatureName2)
                            ExitCode = 'Nothing succeeded'
                        }
                        $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                        $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                        return $windowsFeatureObject
                    }

                    It 'Should throw invalid operation exception when Ensure set to Present' {
                        { Set-TargetResource -Name $script:testWindowsFeatureName2 -Ensure 'Present' } |
                            Should Throw ($script:localizedData.FeatureInstallationFailureError -f $script:testWindowsFeatureName2)
                        Assert-MockCalled -CommandName Add-WindowsFeature -Times 1 -Exactly -Scope It
                    }

                    It 'Should throw invalid operation exception when Ensure set to Absent' {
                        { Set-TargetResource -Name $script:testWindowsFeatureName2 -Ensure 'Absent' } |
                            Should Throw ($script:localizedData.FeatureUninstallationFailureError -f $script:testWindowsFeatureName2)
                        Assert-MockCalled -CommandName Remove-WindowsFeature -Times 1 -Exactly -Scope It
                    }
                }

                Context 'Uninstall/Install with R2/SP1' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $true }

                    Mock -CommandName Invoke-Command -MockWith {
                        $windowsFeature = @{
                            Success = $true
                            RestartNeeded = 'No'
                            FeatureResult = @($script:testWindowsFeatureName2)
                            ExitCode = 'Success'
                        }
                        $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                        $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                        return $windowsFeatureObject
                    }

                    Mock -CommandName 'Add-WindowsFeature' -MockWith { }
                    Mock -CommandName 'Remove-WindowsFeature' -MockWith { }

                    It 'Should install the feature when Ensure set to Present and Credential passed in' {

                        {
                            Set-TargetResource -Name $script:testWindowsFeatureName2 `
                                            -Ensure 'Present' `
                                            -Credential $script:testCredential
                        } | Should -Not -Throw
                        Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope It
                        Assert-MockCalled -CommandName Add-WindowsFeature -Times 0 -Scope It
                    }

                    It 'Should uninstall the feature when Ensure set to Absent and Credential passed in' {

                        {
                            Set-TargetResource -Name $script:testWindowsFeatureName2 `
                                            -Ensure 'Absent' `
                                            -Credential $script:testCredential
                        } | Should -Not -Throw
                        Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope It
                        Assert-MockCalled -CommandName Remove-WindowsFeature -Times 0 -Scope It
                    }
                }
            }

            Describe 'xWindowsFeature/Test-TargetResource' {
                Mock -CommandName Import-ServerManager -MockWith {}

                Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $script:testWindowsFeatureName1 } -MockWith {
                    $windowsFeature = $script:mockWindowsFeatures[$script:testWindowsFeatureName1]
                    $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                    return $windowsFeatureObject
                }

                Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $script:testSubFeatureName1 } -MockWith {
                    $windowsFeature = $script:mockWindowsFeatures[$script:testSubFeatureName1]
                    $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                    return $windowsFeatureObject
                }

                Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $script:testSubFeatureName2 } -MockWith {
                    $windowsFeature = $script:mockWindowsFeatures[$script:testSubFeatureName2]
                    $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                    return $windowsFeatureObject
                }

                Mock -CommandName Get-WindowsFeature -ParameterFilter { $Name -eq $script:testSubFeatureName3 } -MockWith {
                    $windowsFeature = $script:mockWindowsFeatures[$script:testSubFeatureName3]
                    $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                    return $windowsFeatureObject
                }

                # Used as Get-WindowsFeature when on R2/SP1 2008
                Mock -CommandName Invoke-Command -MockWith {
                    $windowsFeature = $script:mockWindowsFeatures[$script:testWindowsFeatureName1]
                    $windowsFeatureObject = New-Object -TypeName PSObject -Property $windowsFeature
                    $windowsFeatureObject.PSTypeNames[0] = 'Microsoft.Windows.ServerManager.Commands.Feature'

                    return $windowsFeatureObject
                }

                Context 'Feature is in the desired state' {
                    It 'Should return true when Ensure set to Absent and Feature not installed' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Absent' `
                                                    -IncludeAllSubFeature $false
                        $testTargetResourceResult | Should -BeTrue
                        Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                    }

                    It 'Should return true when Ensure set to Present and Feature installed not checking subFeatures' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                        $script:mockWindowsFeatures[$script:testWindowsFeatureName1].Installed = $true
                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Present' `
                                                    -IncludeAllSubFeature $false
                        $testTargetResourceResult | Should -BeTrue
                        Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                        $script:mockWindowsFeatures[$script:testWindowsFeatureName1].Installed = $false
                    }

                    It 'Should return true when Ensure set to Present and Feature and subFeatures installed' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                        $script:mockWindowsFeatures[$script:testWindowsFeatureName1].Installed = $true
                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Present' `
                                                    -IncludeAllSubFeature $true
                        $testTargetResourceResult | Should -BeTrue
                        Assert-MockCalled -CommandName Get-WindowsFeature -Times 4 -Exactly -Scope It
                        $script:mockWindowsFeatures[$script:testWindowsFeatureName1].Installed = $false
                    }

                    It 'Should return true when Ensure set to Absent and Feature not installed and on R2/SP1 2008' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $true }

                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Absent' `
                                                    -IncludeAllSubFeature $false `
                                                    -Credential $script:testCredential
                        $testTargetResourceResult | Should -BeTrue
                        Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope It
                    }
                }

                Context 'Feature is not in the desired state' {
                    Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $false }

                    It 'Should return false when Ensure set to Present and Feature not installed' {
                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Present' `
                                                    -IncludeAllSubFeature $false
                        $testTargetResourceResult | Should -BeFalse
                        Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                    }

                    It 'Should return false when Ensure set to Absent and Feature installed not checking subFeatures' {
                        $script:mockWindowsFeatures[$script:testWindowsFeatureName1].Installed = $true
                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Absent' `
                                                    -IncludeAllSubFeature $false
                        $testTargetResourceResult | Should -BeFalse
                        Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                        $script:mockWindowsFeatures[$script:testWindowsFeatureName1].Installed = $false
                    }

                    It 'Should return false when Ensure set to Present, Feature not installed and subFeatures installed' {
                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Present' `
                                                    -IncludeAllSubFeature $true
                        $testTargetResourceResult | Should -BeFalse
                        Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                    }

                    It 'Should return false when Ensure set to Absent and Feature not installed but subFeatures installed' {
                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Absent' `
                                                    -IncludeAllSubFeature $true
                        $testTargetResourceResult | Should -BeFalse
                        Assert-MockCalled -CommandName Get-WindowsFeature -Times 2 -Exactly -Scope It
                    }

                    It 'Should return false when Ensure set to Absent and Feature installed and subFeatures installed' {
                        $script:mockWindowsFeatures[$script:testWindowsFeatureName1].Installed = $true
                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Absent' `
                                                    -IncludeAllSubFeature $true
                        $testTargetResourceResult | Should -BeFalse
                        Assert-MockCalled -CommandName Get-WindowsFeature -Times 1 -Exactly -Scope It
                        $script:mockWindowsFeatures[$script:testWindowsFeatureName1].Installed = $false
                    }

                    It 'Should return false when Ensure set to Present and Feature installed but not all subFeatures installed' {
                        $script:mockWindowsFeatures[$script:testWindowsFeatureName1].Installed = $true
                        $script:mockWindowsFeatures[$script:testSubFeatureName2].Installed = $false
                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Present' `
                                                    -IncludeAllSubFeature $true
                        $testTargetResourceResult | Should -BeFalse
                        Assert-MockCalled -CommandName Get-WindowsFeature -Times 3 -Exactly -Scope It
                        $script:mockWindowsFeatures[$script:testWindowsFeatureName1].Installed = $false
                        $script:mockWindowsFeatures[$script:testSubFeatureName2].Installed = $true
                    }

                    It 'Should return false when Ensure set to Present and Feature not installed and on R2/SP1 2008' {
                        Mock -CommandName Test-IsWinServer2008R2SP1 -MockWith { return $true }

                        $testTargetResourceResult = Test-TargetResource -Name $script:testWindowsFeatureName1 `
                                                    -Ensure 'Present' `
                                                    -IncludeAllSubFeature $false `
                                                    -Credential $script:testCredential
                        $testTargetResourceResult | Should -BeFalse
                        Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope It
                    }
                }
            }

            Describe 'xWindowsFeature/Assert-SingleInstanceOfFeature' {
                $multipleFeature = @(
                    $script:mockWindowsFeatures.Test1
                    $script:mockWindowsFeatures.Test2
                )

                It 'Should throw invalid operation when feature equals null' {
                    $nonexistentName = 'NonexistentFeatureName'

                    { Assert-SingleInstanceOfFeature -Feature $null -Name $nonexistentName } |
                        Should Throw ($script:localizedData.FeatureNotFoundError -f $nonexistentName)
                }

                It 'Should throw invalid operation when there are multiple features with the given name' {
                    { Assert-SingleInstanceOfFeature -Feature $multipleFeature -Name $multipleFeature[0].Name } |
                        Should Throw ($script:localizedData.MultipleFeatureInstancesError -f $multipleFeature[0].Name)
                }
            }

            Describe 'xWindowsFeature/Import-ServerManager' {
                $mockOperatingSystem = @{
                    Name = 'mockOS'
                    Version = '6.1.'
                    OperatingSystemSKU = 10
                }

                Mock -CommandName Get-WmiObject -MockWith { return $mockOperatingSystem }

                It 'Should Not Throw' {
                    Mock -CommandName Import-Module -MockWith {}
                    { Import-ServerManager } | Should -Not -Throw
                }

                It 'Should Not Throw when exception is Identity Reference Runtime Exception' {
                    $mockIdentityReferenceRuntimeException = New-Object -TypeName System.Management.Automation.RuntimeException -ArgumentList 'Some or all identity references could not be translated'
                    Mock -CommandName Import-Module -MockWith { Throw $mockIdentityReferenceRuntimeException }

                    { Import-ServerManager } | Should -Not -Throw
                }

                It 'Should throw invalid operation exception when exception is not Identity Reference Runtime Exception' {
                    $mockOtherRuntimeException = New-Object -TypeName System.Management.Automation.RuntimeException -ArgumentList 'Other error'
                    Mock -CommandName Import-Module -MockWith { Throw $mockOtherRuntimeException }

                    { Import-ServerManager } | Should -Throw ($script:localizedData.SkuNotSupported)
                }

                It 'Should throw invalid operation exception' {
                    Mock -CommandName Import-Module -MockWith { Throw }

                    { Import-ServerManager } | Should -Throw ($script:localizedData.SkuNotSupported)
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
