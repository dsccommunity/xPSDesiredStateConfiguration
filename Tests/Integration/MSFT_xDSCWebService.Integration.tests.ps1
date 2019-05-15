$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceFriendlyName = 'xDSCWebService'
$script:dcsResourceName = "MSFT_$($script:dscResourceFriendlyName)"

#region HEADER
# Integration Test Template Version: 1.3.1
[System.String] $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
    (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone', 'https://github.com/PowerShell/DscResource.Tests.git', (Join-Path -Path $script:moduleRoot -ChildPath 'DscResource.Tests'))
}

# Ensure that Powershell Module 'WebAdministration' is available
if (-not (Install-WindowsFeatureAndVerify -Name Web-Mgmt-Tools))
{
    throw 'Failed to verify for required Windows Feature. Unable to continue ...'
}
Import-Module -Name WebAdministration -ErrorAction:Stop -Force
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'DSCResource.Tests' -ChildPath 'TestHelper.psm1')) -ErrorAction:Stop -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dcsResourceName `
    -TestType Integration

Import-Module -Name (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'CommonTestHelper.psm1') -ErrorAction:Stop -Force

if (Test-SkipContinuousIntegrationTask -Type 'Integration')
{
    return
}

$configurationFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:dcsResourceName).config.ps1"

if ($env:CI -eq $false)
{
    # Install modules
    $requiredModules = Get-ResourceModulesInConfiguration -ConfigurationPath $configurationFile |
        Where-Object -Property Name -ne $script:dscModuleName

    if ($requiredModules)
    {
        Install-DependentModule -Module $requiredModules
    }
}

<#
    .SYNOPSIS
        Performs common DSC integration tests including compiling, setting,
        testing, and getting a configuration.

    .PARAMETER ConfigurationName
        The name of the configuration being executed.
#>
function Invoke-CommonResourceTesting
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ConfigurationName
    )

    It 'Should compile and apply the MOF without throwing' {
        {
            $configurationParameters = @{
                OutputPath           = $TestDrive
                ConfigurationData    = $ConfigurationData
            }

            & $configurationName @configurationParameters

            $startDscConfigurationParameters = @{
                Path         = $TestDrive
                ComputerName = 'localhost'
                Wait         = $true
                Force        = $true
                ErrorAction  = 'Stop'
            }

            Start-DscConfiguration @startDscConfigurationParameters
        } | Should -Not -Throw
    }

    It 'Should be able to call Get-DscConfiguration without throwing' {
        {
            $script:currentConfiguration = Get-DscConfiguration -ErrorAction Stop
        } | Should -Not -Throw
    }

    It 'Should return $true when Test-DscConfiguration is run' {
        Test-DscConfiguration | Should -Be $true
    }
}

<#
    .SYNOPSIS
        Tests if the specified IIS application pool is absent or present

    .PARAMETER ApplicationPoolName
        name of the IIS application pool

    .PARAMETER ResourceState
        state of the IIS application pool
#>
function Test-IISApplicationPool
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ApplicationPoolName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $ResourceState
    )

    $appPoolPath = Join-Path -Path 'IIS:\AppPools' -ChildPath $ApplicationPoolName

    switch ($ResourceState)
    {
        'Present' {
            Test-Path -Path $appPoolPath
        }
        'Absent' {
            -not (Test-Path -Path $appPoolPath)
        }
    }
}

<#
    .SYNOPSIS
        Performs common tests to ensure that the DSC pull server was properly
        installed.

    .PARAMETER WebsiteName
        name of the Pull Server website

    .PARAMETER ResourceState
        state of the resource (website)

    .PARAMETER WebsiteState
        State of the website

    .PARAMETER ApplicationPoolName
        name of the IIS application pool
#>
function Test-DSCPullServer
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $WebsiteName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $ResourceState,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $WebsiteState,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ApplicationPoolName = 'PSWS'
    )

    switch ($ResourceState)
    {
        'Present' {
            It 'Should create a web.config file at the web site root' {
                Test-Path -Path (Join-Path -Path $ConfigurationData.AllNodes.PhysicalPath -ChildPath 'web.config') | Should -Be $true
            }

            It ("Should exist a WebSite called $WebsiteName") {
                Get-WebSite -Name $WebsiteName | Should Not Be $null
            }

            It ("WebSite $WebsiteName should be started") {
                $website = Get-WebSite -Name $WebsiteName
                $website | Should Not Be $null
                $website.state | Should BeExactly $WebsiteState
            }

            It "IIS Application pool $ApplicationPoolName should exist" {
                Test-IISApplicationPool -ApplicationPoolName $ApplicationPoolName -ResourceState 'Present' | Should -Be $true
            }

            It "WebSite $WebsiteName should be bound to IIS applicaiton pool $ApplicationPoolName" {
                $website = Get-WebSite -Name $WebsiteName
                $website | Should Not Be $null
                $website.applicationPool | Should BeExactly $ApplicationPoolName
            }
        }

        'Absent' {
            It ("Should not exist a WebSite called $WebsiteName") {
                Get-WebSite -Name $WebsiteName | Should Be $null
            }
        }
    }
}

<#
    .SYNOPSIS
        Performs a test on defined firewall rules

    .PARAMETER RuleName
        name of the firewall rule

    .PARAMETER ResourceState
        state of the rule
#>
function Test-DSCPullServerFirewallRule
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $RuleName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $ResourceState
    )

    Write-Verbose -Message "Test-DSCPullServerFirewallRule $RuleName for state $ResourceState."

    $expectedRuleCount = 0
    if ('Present' -eq $ResourceState)
    {
        $expectedRuleCount = 1
    }

    It ("Should $(if ('Present' -eq $ResourceState) { '' } else { 'not ' })create a firewall rule $RuleName for the chosen port")  {
        $ruleCnt = (Get-NetFirewallRule | Where-Object -FilterScript {
            $_.DisplayName -eq $RuleName #'DSCPullServer_IIS_Port'
        } | Measure-Object).Count
        Write-Verbose -Message "Found $ruleCnt firewall rules with name '$RuleName'"
        $ruleCnt | Should -Be $expectedRuleCount
    }
}

#endregion

# Using try/finally to always cleanup.
try
{
    # Get a self signed certificate to use with tests
    New-DscSelfSignedCertificate

    if (!(Test-Path -Path env:DscPublicCertificatePath) -or `
        !(Test-Path -Path env:DscCertificateThumbprint))
    {
        throw "A DSC certificate is required for $script:dscResourceFriendlyName integration tests."
    }

    # Make sure the DSC-Service and Web-Server Windows features are installed
    if (!(Install-WindowsFeatureAndVerify -Name 'DSC-Service') -or
        !(Install-WindowsFeatureAndVerify -Name 'Web-Server'))
    {
        Write-Verbose -Message 'Skipping xDSCWebService Integration tests due to missing Windows Features.' -Verbose
        return
    }

    # Make sure the w3svc is running before proceeding with tests
    Start-Service -Name w3svc -ErrorAction Stop

    #region Integration Tests
    . $configurationFile

    Describe "$($script:dcsResourceName)_Integration" {
        $ensureAbsentConfigurationName = 'MSFT_xDSCWebService_PullTestRemoval_Config'

        $ensurePresentConfigurationNames = @(
            'MSFT_xDSCWebService_PullTestWithSecurityBestPractices_Config',
            'MSFT_xDSCWebService_PullTestWithoutSecurityBestPractices_Config'
        )

        foreach ($configurationName in $ensurePresentConfigurationNames)
        {
            Context ('When using configuration {0}' -f $configurationName) {
                BeforeAll {
                    Invoke-CommonResourceTesting -ConfigurationName $ensureAbsentConfigurationName
                }

                AfterAll {
                    Invoke-CommonResourceTesting -ConfigurationName $ensureAbsentConfigurationName
                }

                Invoke-CommonResourceTesting -ConfigurationName $configurationName

                Test-DSCPullServer -WebsiteName 'PSDSCPullServer' -ResourceState 'Present' -WebsiteState 'Started'
                Test-DSCPullServerFirewallRule -RuleName 'DSCPullServer_IIS_Port' -ResourceState 'Present'
            }
        }

        Context 'Verify clean removal' {

            BeforeAll {
                Invoke-CommonResourceTesting -ConfigurationName $ensureAbsentConfigurationName
            }

            Invoke-CommonResourceTesting -ConfigurationName 'MSFT_xDSCWebService_PullTestWithSecurityBestPractices_Config'

            Test-DSCPullServer -WebsiteName 'PSDSCPullServer' -ResourceState 'Present' -WebsiteState 'Started'
            Test-DSCPullServerFirewallRule -RuleName 'DSCPullServer_IIS_Port' -ResourceState 'Present'

            Invoke-CommonResourceTesting -ConfigurationName $ensureAbsentConfigurationName

            Test-DSCPullServer -WebsiteName 'PSDSCPullServer' -ResourceState 'Absent' -WebsiteState 'Absent'
            Test-DSCPullServerFirewallRule -RuleName 'DSCPullServer_IIS_Port' -ResourceState 'Absent'
        }

        Context 'No firewall configuration' {
            $configurationName = 'MSFT_xDSCWebService_PullTestWithoutFirewall_Config'

            BeforeAll {
                Invoke-CommonResourceTesting -ConfigurationName $ensureAbsentConfigurationName
            }

            AfterAll {
                Invoke-CommonResourceTesting -ConfigurationName $ensureAbsentConfigurationName
            }

            Invoke-CommonResourceTesting -ConfigurationName $configurationName

            Test-DSCPullServer -WebsiteName 'PSDSCPullServer' -ResourceState 'Present' -WebsiteState 'Started'
            Test-DSCPullServerFirewallRule -RuleName 'DSCPullServer_IIS_Port' -ResourceState 'Absent'
        }

        Context 'Separate firewall role definition' {

            BeforeAll {
                Invoke-CommonResourceTesting -ConfigurationName $ensureAbsentConfigurationName
            }

            Invoke-CommonResourceTesting -ConfigurationName 'MSFT_xDSCWebService_PullTestWithSeparateFirewallRule_Config'
            Test-DSCPullServer -WebsiteName 'PSDSCPullServer' -ResourceState 'Present' -WebsiteState 'Started'
            Test-DSCPullServerFirewallRule -RuleName 'DSCPullServer_IIS_Port' -ResourceState 'Absent'
            Test-DSCPullServerFirewallRule -RuleName 'DSC PullServer 8080' -ResourceState 'Present'


            Invoke-CommonResourceTesting -ConfigurationName $ensureAbsentConfigurationName
            Test-DSCPullServer -WebsiteName 'PSDSCPullServer' -ResourceState 'Absent' -WebsiteState 'Absent'
            Test-DSCPullServerFirewallRule -RuleName 'DSCPullServer_IIS_Port' -ResourceState 'Absent'
            Test-DSCPullServerFirewallRule -RuleName 'DSC PullServer 8080' -ResourceState 'Present'
        }

        Context 'Separate IIS application pool definition' {

            BeforeAll {
                Invoke-CommonResourceTesting -ConfigurationName $ensureAbsentConfigurationName
            }

            Invoke-CommonResourceTesting -ConfigurationName 'MSFT_xDSCWebService_PullTestSeparateAppPool_Config'
            Test-DSCPullServer -WebsiteName 'PSDSCPullServer' -ResourceState 'Present' -WebsiteState 'Started' -ApplicationPoolName 'PSDSCPullServer_PSDSCPullServer'
            Test-DSCPullServerFirewallRule -RuleName 'DSCPullServer_IIS_Port' -ResourceState 'Absent'

            Invoke-CommonResourceTesting -ConfigurationName $ensureAbsentConfigurationName
            Test-DSCPullServer -WebsiteName 'PSDSCPullServer' -ResourceState 'Absent' -WebsiteState 'Absent'
            Test-DSCPullServerFirewallRule -RuleName 'DSCPullServer_IIS_Port' -ResourceState 'Absent'

            It "Separately created IIS Application pool should still exist after cleanup" {
                Test-IISApplicationPool -ApplicationPoolName 'PSDSCPullServer_PSDSCPullServer' -ResourceState 'Present' | Should -Be $true
            }

        }
    }
    #endregion

}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
