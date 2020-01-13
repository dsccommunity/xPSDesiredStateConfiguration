$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xPackageResource'

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
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\DSC_xPackageResource.TestHelper.psm1')
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
        Describe 'xPackageResource Unit Tests' {
            BeforeAll {
                function Set-DSCMachineRebootRequired
                {
                }

                $script:skipHttpsTest = $true

                $script:testDirectoryPath = Join-Path -Path $TestDrive -ChildPath 'MSFT_xPackageResource.Tests'

                if (Test-Path -Path $script:testDirectoryPath)
                {
                    $null = Remove-Item -Path $script:testDirectoryPath -Recurse -Force
                }

                $null = New-Item -Path $script:testDirectoryPath -ItemType 'Directory'

                <#
                    This log file is used to log messages from the mock server which is important for debugging since
                    most of the work of the mock server is done within a separate process.
                #>
                $script:logFile = Join-Path -Path $TestDrive -ChildPath 'PackageTestLogFile.txt'

                $script:msiName = 'DSCSetupProject.msi'
                $script:msiLocation = Join-Path -Path $script:testDirectoryPath -ChildPath $script:msiName
                $script:msiArguments = '/NoReboot'
                $script:packageName = 'DSCUnitTestPackage'
                $script:packageId = '{deadbeef-80c6-41e6-a1b9-8bdb8a05027f}'

                $null = New-TestMsi -DestinationPath $script:msiLocation

                $script:testHttpPort = Get-UnusedTcpPort
                $script:testHttpsPort = Get-UnusedTcpPort -ExcludePorts @($script:testHttpPort)

                $script:testExecutablePath = Join-Path -Path $script:testDirectoryPath -ChildPath 'TestExecutable.exe'

                $null = New-TestExecutable -DestinationPath $script:testExecutablePath

                $null = Clear-PackageCache
            }

            AfterAll {
                $null = Clear-PackageCache

                if (Test-PackageInstalledByName -Name $script:packageName)
                {
                    $null = Start-Process -FilePath 'msiexec.exe' -ArgumentList @("/x$script:packageId", '/passive') -Wait
                    $null = Start-Sleep -Seconds 1
                }

                if (Test-PackageInstalledByName -Name $script:packageName)
                {
                    throw 'Test output will not be valid - package could not be removed.'
                }
            }

            Describe 'xPackageResource' {
                BeforeEach {
                    $null = Clear-PackageCache

                    if (Test-PackageInstalledByName -Name $script:packageName)
                    {
                        $null = Start-Process -FilePath 'msiexec.exe' -ArgumentList @("/x$script:packageId", '/passive') -Wait
                        $null = Start-Sleep -Seconds 1
                    }

                    if (Test-PackageInstalledByName -Name $script:packageName)
                    {
                        throw 'Package could not be removed.'
                    }
                }

                Context 'xPackageResource\Get-TargetResource' {
                    It 'Should return only basic properties for absent package' {
                        $packageParameters = @{
                            Path      = $script:msiLocation
                            Name      = $script:packageName
                            ProductId = $script:packageId
                        }

                        $getTargetResourceResult = Get-TargetResource @packageParameters
                        $getTargetResourceResultProperties = @( 'Ensure', 'Name', 'ProductId', 'Installed' )

                        Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargetResourceResultProperties
                    }

                    It 'Should return basic and registry properties for present package with registry check parameters specified and CreateCheckRegValue true' {
                        $packageParameters = @{
                            Path                       = $script:msiLocation
                            Name                       = $script:packageName
                            ProductId                  = $script:packageId
                            CreateCheckRegValue        = $true
                            InstalledCheckRegHive      = 'LocalMachine'
                            InstalledCheckRegKey       = 'SOFTWARE\xPackageTestKey'
                            InstalledCheckRegValueName = 'xPackageTestValue'
                            InstalledCheckRegValueData = 'installed'
                        }

                        Set-TargetResource -Ensure 'Present' @packageParameters

                        try
                        {
                            Clear-PackageCache

                            $getTargetResourceResult = Get-TargetResource @packageParameters
                            $getTargetResourceResultProperties = @( 'Ensure', 'Name', 'ProductId', 'Installed', 'CreateCheckRegValue', 'InstalledCheckRegHive', 'InstalledCheckRegKey', 'InstalledCheckRegValueName', 'InstalledCheckRegValueData' )

                            Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargetResourceResultProperties
                        }
                        finally
                        {
                            $baseRegistryKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
                            $baseRegistryKey.DeleteSubKeyTree($packageParameters.InstalledCheckRegKey)
                        }
                    }

                    It 'Should return full package properties for present package with registry check parameters specified and CreateCheckRegValue false' {
                        $packageParameters = @{
                            Path                       = $script:msiLocation
                            Name                       = $script:packageName
                            ProductId                  = $script:packageId
                            CreateCheckRegValue        = $false
                            InstalledCheckRegKey       = ''
                            InstalledCheckRegValueName = ''
                            InstalledCheckRegValueData = ''
                        }

                        Set-TargetResource -Ensure 'Present' @packageParameters
                        Clear-PackageCache

                        $getTargetResourceResult = Get-TargetResource @packageParameters
                        $getTargetResourceResultProperties = @( 'Ensure', 'Name', 'ProductId', 'Installed', 'Path', 'InstalledOn', 'Size', 'Version', 'PackageDescription', 'Publisher' )

                        Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargetResourceResultProperties
                    }

                    It 'Should return full package properties for present package without registry check parameters specified' {
                        $packageParameters = @{
                            Path      = $script:msiLocation
                            Name      = $script:packageName
                            ProductId = $script:packageId
                        }

                        Set-TargetResource -Ensure 'Present' @packageParameters
                        Clear-PackageCache

                        $getTargetResourceResult = Get-TargetResource @packageParameters
                        $getTargetResourceResultProperties = @( 'Ensure', 'Name', 'ProductId', 'Installed', 'Path', 'InstalledOn', 'Size', 'Version', 'PackageDescription', 'Publisher' )

                        Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargetResourceResultProperties
                    }
                }

                Context 'xPackageResource\Test-TargetResource' {
                    It 'Should return correct value when package is absent' {
                        $testTargetResourceResult = Test-TargetResource `
                            -Ensure 'Present' `
                            -Path $script:msiLocation `
                            -ProductId $script:packageId `
                            -Name ([System.String]::Empty)

                        $testTargetResourceResult | Should -BeFalse

                        $testTargetResourceResult = Test-TargetResource `
                            -Ensure 'Present' `
                            -Path $script:msiLocation `
                            -Name $script:packageName `
                            -ProductId ([System.String]::Empty)

                        $testTargetResourceResult | Should -BeFalse

                        $testTargetResourceResult = Test-TargetResource `
                            -Ensure 'Absent' `
                            -Path $script:msiLocation `
                            -ProductId $script:packageId `
                            -Name ([System.String]::Empty)

                        $testTargetResourceResult | Should -BeTrue

                        $testTargetResourceResult = Test-TargetResource `
                            -Ensure 'Absent' `
                            -Path $script:msiLocation `
                            -Name $script:packageName `
                            -ProductId ([System.String]::Empty)

                        $testTargetResourceResult | Should -BeTrue
                    }

                    It 'Should return correct value when package is present without registry parameters' {
                        Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId $script:packageId -Name ([System.String]::Empty)

                        Clear-PackageCache

                        Test-PackageInstalledByName -Name $script:packageName | Should -BeTrue

                        $testTargetResourceResult = Test-TargetResource `
                            -Ensure 'Present' `
                            -Path $script:msiLocation `
                            -ProductId $script:packageId `
                            -Name ([System.String]::Empty)

                        $testTargetResourceResult | Should -BeTrue

                        $testTargetResourceResult = Test-TargetResource `
                            -Ensure 'Present' `
                            -Path $script:msiLocation `
                            -Name $script:packageName `
                            -ProductId ([System.String]::Empty)

                        $testTargetResourceResult | Should -BeTrue

                        $testTargetResourceResult = Test-TargetResource `
                            -Ensure 'Absent' `
                            -Path $script:msiLocation `
                            -ProductId $script:packageId `
                            -Name ([System.String]::Empty)

                        $testTargetResourceResult | Should -BeFalse

                        $testTargetResourceResult = Test-TargetResource `
                            -Ensure 'Absent' `
                            -Path $script:msiLocation `
                            -Name $script:packageName `
                            -ProductId ([System.String]::Empty)

                        $testTargetResourceResult | Should -BeFalse
                    }

                    $existingPackageParameters = @{
                        Path                       = $script:testExecutablePath
                        Name                       = [System.String]::Empty
                        ProductId                  = [System.String]::Empty
                        CreateCheckRegValue        = $true
                        InstalledCheckRegHive      = 'LocalMachine'
                        InstalledCheckRegKey       = 'SOFTWARE\xPackageTestKey'
                        InstalledCheckRegValueName = 'xPackageTestValue'
                        InstalledCheckRegValueData = 'installed'
                    }

                    It 'Should return present with existing exe and matching registry parameters' {
                        Set-TargetResource -Ensure 'Present' @existingPackageParameters

                        try
                        {
                            $testTargetResourceResult = Test-TargetResource -Ensure 'Present' @existingPackageParameters
                            $testTargetResourceResult | Should -BeTrue

                            $testTargetResourceResult = Test-TargetResource -Ensure 'Absent' @existingPackageParameters
                            $testTargetResourceResult | Should -BeFalse
                        }
                        finally
                        {
                            $baseRegistryKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
                            $baseRegistryKey.DeleteSubKeyTree($existingPackageParameters.InstalledCheckRegKey)
                        }
                    }

                    $parametersToMismatchCheck = @( 'InstalledCheckRegKey', 'InstalledCheckRegValueName', 'InstalledCheckRegValueData' )

                    foreach ($parameterToMismatchCheck in $parametersToMismatchCheck)
                    {
                        It "Should return not present with existing exe and mismatching parameter $parameterToMismatchCheck" {
                            Set-TargetResource -Ensure 'Present' @existingPackageParameters

                            try
                            {
                                $mismatchingParameters = $existingPackageParameters.Clone()
                                $mismatchingParameters[$parameterToMismatchCheck] = 'not original value'

                                Write-Verbose -Message "Test target resource parameters: $( Out-String -InputObject $mismatchingParameters)"

                                $testTargetResourceResult = Test-TargetResource -Ensure 'Present' @mismatchingParameters
                                $testTargetResourceResult | Should -BeFalse

                                $testTargetResourceResult = Test-TargetResource -Ensure 'Absent' @mismatchingParameters
                                $testTargetResourceResult | Should -BeTrue
                            }
                            finally
                            {
                                $baseRegistryKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
                                $baseRegistryKey.DeleteSubKeyTree($existingPackageParameters.InstalledCheckRegKey)
                            }
                        }
                    }
                }

                Context 'xPackageResource\Set-TargetResource' {
                    It 'Should correctly install and remove a .msi package without registry parameters' {
                        Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId $script:packageId -Name ([System.String]::Empty)

                        Test-PackageInstalledByName -Name $script:packageName | Should -BeTrue

                        $getTargetResourceResult = Get-TargetResource -Path $script:msiLocation -ProductId $script:packageId -Name ([System.String]::Empty)

                        $getTargetResourceResult.Version | Should -Be '1.2.3.4'
                        $getTargetResourceResult.InstalledOn | Should -Be ('{0:d}' -f [System.DateTime]::Now.Date)
                        $getTargetResourceResult.Installed | Should -BeTrue
                        $getTargetResourceResult.ProductId | Should -Be $script:packageId
                        $getTargetResourceResult.Path | Should -Be $script:msiLocation

                        # Can't figure out how to set this within the MSI.
                        # $getTargetResourceResult.PackageDescription | Should -Be 'A package for unit testing'

                        [Math]::Round($getTargetResourceResult.Size, 2) | Should -Be 0.03

                        Set-TargetResource -Ensure 'Absent' -Path $script:msiLocation -ProductId $script:packageId -Name ([System.String]::Empty)

                        Test-PackageInstalledByName -Name $script:packageName | Should -BeFalse
                    }

                    It 'Should correctly install and remove a .msi package with registry parameters' {
                        $packageParameters = @{
                            Path                       = $script:msiLocation
                            Name                       = [System.String]::Empty
                            ProductId                  = $script:packageId
                            CreateCheckRegValue        = $true
                            InstalledCheckRegHive      = 'LocalMachine'
                            InstalledCheckRegKey       = 'SOFTWARE\xPackageTestKey'
                            InstalledCheckRegValueName = 'xPackageTestValue'
                            InstalledCheckRegValueData = 'installed'
                        }

                        Set-TargetResource -Ensure 'Present' @packageParameters

                        try
                        {
                            Test-PackageInstalledByName -Name $script:packageName | Should -BeTrue

                            $getTargetResourceResult = Get-TargetResource @packageParameters

                            $getTargetResourceResult.Installed | Should -BeTrue
                            $getTargetResourceResult.ProductId | Should -Be $packageParameters.ProductId
                            $getTargetResourceResult.Path | Should -Be $packageParameters.Path
                            $getTargetResourceResult.Name | Should -Be $packageParameters.Name
                            $getTargetResourceResult.CreateCheckRegValue | Should -Be $packageParameters.CreateCheckRegValue
                            $getTargetResourceResult.InstalledCheckRegHive | Should -Be $packageParameters.InstalledCheckRegHive
                            $getTargetResourceResult.InstalledCheckRegKey | Should -Be $packageParameters.InstalledCheckRegKey
                            $getTargetResourceResult.InstalledCheckRegValueName | Should -Be $packageParameters.InstalledCheckRegValueName
                            $getTargetResourceResult.InstalledCheckRegValueData | Should -Be $packageParameters.InstalledCheckRegValueData

                            Set-TargetResource -Ensure 'Absent' @packageParameters

                            Test-PackageInstalledByName -Name $script:packageName | Should -BeFalse
                        }
                        finally
                        {
                            $baseRegistryKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
                            $baseRegistryKey.DeleteSubKeyTree($packageParameters.InstalledCheckRegKey)
                        }
                    }

                    It 'Should correctly install and remove a .exe package with registry parameters' {
                        $packageParameters = @{
                            Path                       = $script:testExecutablePath
                            Name                       = [System.String]::Empty
                            ProductId                  = [System.String]::Empty
                            CreateCheckRegValue        = $true
                            InstalledCheckRegHive      = 'LocalMachine'
                            InstalledCheckRegKey       = 'SOFTWARE\xPackageTestKey'
                            InstalledCheckRegValueName = 'xPackageTestValue'
                            InstalledCheckRegValueData = 'installed'
                        }

                        Set-TargetResource -Ensure 'Present' @packageParameters

                        try
                        {
                            Test-TargetResource -Ensure 'Present' @packageParameters | Should -BeTrue

                            $getTargetResourceResult = Get-TargetResource @packageParameters

                            $getTargetResourceResult.Installed | Should -BeTrue
                            $getTargetResourceResult.ProductId | Should -Be $packageParameters.ProductId
                            $getTargetResourceResult.Path | Should -Be $packageParameters.Path
                            $getTargetResourceResult.Name | Should -Be $packageParameters.Name
                            $getTargetResourceResult.CreateCheckRegValue | Should -Be $packageParameters.CreateCheckRegValue
                            $getTargetResourceResult.InstalledCheckRegHive | Should -Be $packageParameters.InstalledCheckRegHive
                            $getTargetResourceResult.InstalledCheckRegKey | Should -Be $packageParameters.InstalledCheckRegKey
                            $getTargetResourceResult.InstalledCheckRegValueName | Should -Be $packageParameters.InstalledCheckRegValueName
                            $getTargetResourceResult.InstalledCheckRegValueData | Should -Be $packageParameters.InstalledCheckRegValueData

                            Set-TargetResource -Ensure 'Absent' @packageParameters

                            Test-TargetResource -Ensure 'Absent' @packageParameters | Should -BeTrue
                        }
                        finally
                        {
                            $baseRegistryKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
                            $baseRegistryKey.DeleteSubKeyTree($packageParameters.InstalledCheckRegKey)
                        }
                    }

                    It 'Should throw with incorrect product id' {
                        $wrongPackageId = '{deadbeef-80c6-41e6-a1b9-8bdb8a050272}'

                        { Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId $wrongPackageId -Name ([System.String]::Empty) } | Should -Throw
                    }

                    It 'Should throw with incorrect name' {
                        $wrongPackageName = 'WrongPackageName'

                        { Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId ([System.String]::Empty) -Name $wrongPackageName } | Should -Throw
                    }

                    It 'Should correctly install and remove a package from a HTTP URL' {
                        $uriBuilder = [System.UriBuilder]::new('http', 'localhost', $script:testHttpPort)
                        $baseUrl = $uriBuilder.Uri.AbsoluteUri

                        $uriBuilder.Path = 'package.msi'
                        $msiUrl = $uriBuilder.Uri.AbsoluteUri

                        $fileServerStarted = $null
                        $job = $null

                        try
                        {
                            'Http tests:' >> $script:logFile

                            # Make sure no existing HTTP(S) test servers are running
                            Stop-EveryTestServerInstance

                            $serverResult = Start-Server -FilePath $script:msiLocation -LogPath $script:logFile -Https $false -HttpPort $script:testHttpPort -HttpsPort $script:testHttpsPort
                            $fileServerStarted = $serverResult.FileServerStarted
                            $job = $serverResult.Job

                            # Wait for the file server to be ready to receive requests
                            $fileServerStarted.WaitOne(30000)

                            { Set-TargetResource -Ensure 'Present' -Path $baseUrl -Name $script:packageName -ProductId $script:packageId } | Should -Throw

                            Set-TargetResource -Ensure 'Present' -Path $msiUrl -Name $script:packageName -ProductId $script:packageId
                            Test-PackageInstalledByName -Name $script:packageName | Should -BeTrue

                            Set-TargetResource -Ensure 'Absent' -Path $msiUrl -Name $script:packageName -ProductId $script:packageId
                            Test-PackageInstalledByName -Name $script:packageName | Should -BeFalse
                        }
                        catch
                        {
                            Write-Warning -Message 'Caught exception performing HTTP server tests. Outputting HTTP server log.' -Verbose
                            Get-Content -Path $script:logFile | Write-Verbose -Verbose
                            throw $_
                        }
                        finally
                        {
                            <#
                                This must be called after Start-Server to ensure the listening port is closed,
                                otherwise subsequent tests may fail until the machine is rebooted.
                            #>
                            Stop-Server -FileServerStarted $fileServerStarted -Job $job
                        }
                    }

                    It 'Should correctly install and remove a package from a HTTPS URL' -Skip:$script:skipHttpsTest {
                        $uriBuilder = [System.UriBuilder]::new('https', 'localhost', $script:testHttpsPort)
                        $baseUrl = $uriBuilder.Uri.AbsoluteUri

                        $uriBuilder.Path = 'package.msi'
                        $msiUrl = $uriBuilder.Uri.AbsoluteUri

                        $fileServerStarted = $null
                        $job = $null

                        try
                        {
                            'Https tests:' >> $script:logFile

                            # Make sure no existing HTTP(S) test servers are running
                            Stop-EveryTestServerInstance

                            $serverResult = Start-Server -FilePath $script:msiLocation -LogPath $script:logFile -Https $true -HttpPort $script:testHttpPort -HttpsPort $script:testHttpsPort
                            $fileServerStarted = $serverResult.FileServerStarted
                            $job = $serverResult.Job

                            # Wait for the file server to be ready to receive requests
                            $fileServerStarted.WaitOne(30000)

                            { Set-TargetResource -Ensure 'Present' -Path $baseUrl -Name $script:packageName -ProductId $script:packageId } | Should -Throw

                            Set-TargetResource -Ensure 'Present' -Path $msiUrl -Name $script:packageName -ProductId $script:packageId
                            Test-PackageInstalledByName -Name $script:packageName | Should -BeTrue

                            Set-TargetResource -Ensure 'Absent' -Path $msiUrl -Name $script:packageName -ProductId $script:packageId
                            Test-PackageInstalledByName -Name $script:packageName | Should -BeFalse
                        }
                        catch
                        {
                            Write-Warning -Message 'Caught exception performing HTTPS server tests. Outputting HTTPS server log.' -Verbose
                            Get-Content -Path $script:logFile | Write-Verbose -Verbose
                            throw $_
                        }
                        finally
                        {
                            <#
                                This must be called after Start-Server to ensure the listening port is closed,
                                otherwise subsequent tests may fail until the machine is rebooted.
                            #>
                            Stop-Server -FileServerStarted $fileServerStarted -Job $job
                        }
                    }

                    It 'Should write to the specified log path' {
                        $logPath = Join-Path -Path $script:testDirectoryPath -ChildPath 'TestMsiLog.txt'

                        if (Test-Path -Path $logPath)
                        {
                            Remove-Item -Path $logPath -Force
                        }

                        Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -Name $script:packageName -LogPath $logPath -ProductId ([System.String]::Empty)

                        Test-Path -Path $logPath | Should -BeTrue
                        Get-Content -Path $logPath | Should -Not -Be $null
                    }

                    It 'Should add space after .MSI installation arguments (#195)' {
                        Mock Invoke-Process -ParameterFilter { $Process.StartInfo.Arguments.EndsWith($script:msiArguments) } {
                            return @{
                                ExitCode = 0
                            }
                        }
                        Mock Test-TargetResource { return $false }
                        Mock Get-ProductEntry { return $script:packageId }

                        $packageParameters = @{
                            Path      = $script:msiLocation
                            Name      = [System.String]::Empty
                            ProductId = $script:packageId
                            Arguments = $script:msiArguments
                        }

                        Set-TargetResource -Ensure 'Present' @packageParameters

                        Assert-MockCalled Invoke-Process -ParameterFilter { $Process.StartInfo.Arguments.EndsWith(" $script:msiArguments") } -Scope It
                    }

                    It 'Should not check for product installation when rebooted is required (#52)' {
                        Mock -CommandName 'Invoke-Process' -MockWith {
                            return [System.Management.Automation.PSObject] @{
                                ExitCode = 3010
                            }
                        }
                        Mock -CommandName 'Test-TargetResource' -MockWith { return $false }
                        Mock -CommandName 'Get-ProductEntry' -MockWith { return $null }
                        Mock -CommandName 'Set-DSCMachineRebootRequired' -MockWith { }

                        $packageParameters = @{
                            Path      = $script:msiLocation
                            Name      = [System.String]::Empty
                            ProductId = $script:packageId
                        }

                        { Set-TargetResource -Ensure 'Present' @packageParameters } | Should -Not -Throw

                        Assert-MockCalled -CommandName Set-DSCMachineRebootRequired -Times 1 -Scope It
                    }

                    It 'Should not run Set-DSCMachineRebootRequired if IgnoreReboot provided' {
                        Mock -CommandName 'Invoke-Process' -MockWith {
                            return [System.Management.Automation.PSObject] @{
                                ExitCode = 3010
                            }
                        }
                        Mock -CommandName 'Test-TargetResource' -MockWith { return $false }
                        Mock -CommandName 'Get-ProductEntry' -MockWith { return $null }
                        Mock -CommandName 'Set-DSCMachineRebootRequired' -MockWith { }

                        $packageParameters = @{
                            Path         = $script:msiLocation
                            Name         = [System.String]::Empty
                            ProductId    = $script:packageId
                            IgnoreReboot = $true
                        }

                        { Set-TargetResource -Ensure 'Present' @packageParameters } | Should -Not -Throw

                        Assert-MockCalled -CommandName Set-DSCMachineRebootRequired -Times 0 -Scope It
                    }

                    It 'Should install package using user credentials when specified' {
                        Mock Invoke-PInvoke { }
                        Mock Test-TargetResource { return $false }
                        Mock Get-ProductEntry { return $script:packageId }

                        $packageCredential = [System.Management.Automation.PSCredential]::Empty
                        $packageParameters = @{
                            Path            = $script:msiLocation
                            Name            = [System.String]::Empty
                            ProductId       = $script:packageId
                            RunAsCredential = $packageCredential
                        }
                        Set-TargetResource -Ensure 'Present' @packageParameters

                        Assert-MockCalled Invoke-PInvoke -ParameterFilter { $Credential -eq $packageCredential } -Scope It
                    }
                }

                Context 'xPackageResource\Get-MsiTool' {
                    It 'Should add MSI tools in the Microsoft.Windows.DesiredStateConfiguration.xPackageResource namespace' {
                        $addTypeResult = @{
                            Namespace = 'Mock not called'
                        }
                        Mock -CommandName 'Add-Type' -MockWith {
                            $addTypeResult['Namespace'] = $Namespace
                        }

                        $msiTool = Get-MsiTool

                        if (([System.Management.Automation.PSTypeName]'Microsoft.Windows.DesiredStateConfiguration.xPackageResource.MsiTools').Type)
                        {
                            Assert-MockCalled -CommandName 'Add-Type' -Times 0

                            $msiTool | Should -Be ([System.Management.Automation.PSTypeName]'Microsoft.Windows.DesiredStateConfiguration.xPackageResource.MsiTools').Type
                        }
                        else
                        {
                            Assert-MockCalled -CommandName 'Add-Type' -Times 1

                            $addTypeResult['Namespace'] | Should -Be 'Microsoft.Windows.DesiredStateConfiguration.xPackageResource'
                            $msiTool | Should -Be $null
                        }
                    }
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
