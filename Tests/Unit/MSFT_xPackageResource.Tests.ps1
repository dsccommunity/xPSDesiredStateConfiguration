Import-Module "$PSScriptRoot\..\CommonTestHelper.psm1" -Force

$script:dscResourceModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'MSFT_xPackageResource'
$script:testType = 'Unit'

Initialize-DscResourceUnitTest `
    -DscResourceModuleName $script:dscResourceModuleName `
    -DscResourceName $script:dscResourceName `
    -TestType $script:testType `
| Out-Null

InModuleScope "$script:dscResourceName" {
    Describe "$script:dscResourceName $script:testType Tests" {
        BeforeAll {
            Import-Module "$PSScriptRoot\MSFT_xPackageResource.TestHelper.psm1" -Force

            $script:skipHttpsTest = $true

            $script:testDirectoryPath = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_xPackageResourceTests'

            if (Test-Path -Path $script:testDirectoryPath)
            {
                Remove-Item -Path $script:testDirectoryPath -Recurse -Force | Out-Null
            }

            New-Item -Path $script:testDirectoryPath -ItemType 'Directory' | Out-Null

            $script:msiName = 'DSCSetupProject.msi'
            $script:msiLocation = Join-Path -Path $script:testDirectoryPath -ChildPath $script:msiName
            
            $script:packageName = 'DSCUnitTestPackage'
            $script:packageId = '{deadbeef-80c6-41e6-a1b9-8bdb8a05027f}'

            New-TestMsi -DestinationPath $script:msiLocation | Out-Null

            $script:testExecutablePath = Join-Path -Path $script:testDirectoryPath -ChildPath 'TestExecutable.exe'
            New-TestExecutable -DestinationPath $script:testExecutablePath | Out-Null

            Clear-xPackageCache | Out-Null
        }

        BeforeEach {
            Clear-xPackageCache | Out-Null

            if (Test-PackageInstalled -Name $script:packageName)
            {
                Start-Process -FilePath 'msiexec.exe' -ArgumentList @("/x$script:packageId", '/passive') -Wait | Out-Null
                Start-Sleep -Seconds 1 | Out-Null
            }
        
            if (Test-PackageInstalled -Name $script:packageName)
            {
                throw 'Test output will not be valid - package could not be removed.'
            }
        }

        AfterAll {
            if (Test-Path -Path $script:testDirectoryPath)
            {
                Remove-Item -Path $script:testDirectoryPath -Recurse -Force | Out-Null
            }

            Clear-xPackageCache | Out-Null

            if (Test-PackageInstalled -Name $script:packageName)
            {
                Start-Process -FilePath 'msiexec.exe' -ArgumentList @("/x$script:packageId", '/passive') -Wait | Out-Null
                Start-Sleep -Seconds 1 | Out-Null
            }
        
            if (Test-PackageInstalled -Name $script:packageName)
            {
                throw 'Test output will not be valid - package could not be removed.'
            }
        }

        Context 'Test-TargetResource' {
            It 'Should return correct value when package is absent' {
                $testTargetResourceResult = Test-TargetResource `
                    -Ensure 'Present' `
                    -Path $script:msiLocation `
                    -ProductId $script:packageId `
                    -Name ([String]::Empty)
                                 
                $testTargetResourceResult | Should Be $false
        
                $testTargetResourceResult = Test-TargetResource `
                    -Ensure 'Present' `
                    -Path $script:msiLocation `
                    -Name $script:packageName `
                    -ProductId ([String]::Empty)

                $testTargetResourceResult | Should Be $false
        
                $testTargetResourceResult = Test-TargetResource `
                    -Ensure 'Absent' `
                    -Path $script:msiLocation `
                    -ProductId $script:packageId `
                    -Name ([String]::Empty)

                $testTargetResourceResult | Should Be $true
        
                $testTargetResourceResult = Test-TargetResource `
                    -Ensure 'Absent' `
                    -Path $script:msiLocation `
                    -Name $script:packageName `
                    -ProductId ([String]::Empty)

                $testTargetResourceResult | Should Be $true
            }

            It 'Should return correct value when package is present' {
                Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId $script:packageId -Name ([String]::Empty)
            
                Clear-xPackageCache

                Test-PackageInstalled -Name $script:packageName | Should Be $true
        
                $testTargetResourceResult = Test-TargetResource `
                        -Ensure 'Present' `
                        -Path $script:msiLocation `
                        -ProductId $script:packageId `
                        -Name ([String]::Empty)
                                 
                $testTargetResourceResult | Should Be $true
        
                $testTargetResourceResult = Test-TargetResource `
                    -Ensure 'Present' `
                    -Path $script:msiLocation `
                    -Name $script:packageName `
                    -ProductId ([String]::Empty)

                $testTargetResourceResult | Should Be $true
        
                $testTargetResourceResult = Test-TargetResource `
                    -Ensure 'Absent' `
                    -Path $script:msiLocation `
                    -ProductId $script:packageId `
                    -Name ([String]::Empty)

                $testTargetResourceResult | Should Be $false
        
                $testTargetResourceResult = Test-TargetResource `
                    -Ensure 'Absent' `
                    -Path $script:msiLocation `
                    -Name $script:packageName `
                    -ProductId ([String]::Empty)

                $testTargetResourceResult | Should Be $false
            }
        }

        Context 'Set-TargetResource' {
            It 'Should correctly install and remove a package' {
                Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId $script:packageId -Name ([String]::Empty)

                Test-PackageInstalled -Name $script:packageName | Should Be $true
        
                $getTargetResourceResult = Get-TargetResource -Path $script:msiLocation -ProductId $script:packageId -Name ([String]::Empty)
                
                $getTargetResourceResult.Version | Should Be '1.2.3.4'
                $getTargetResourceResult.InstalledOn | Should Be ("{0:d}" -f [DateTime]::Now.Date)
                $getTargetResourceResult.Installed | Should Be $true
                $getTargetResourceResult.ProductId | Should Be $script:packageId
                $getTargetResourceResult.Path | Should Be $script:msiLocation

                # Can't figure out how to set this within the MSI.
                # $getTargetResourceResult.PackageDescription | Should Be 'A package for unit testing'

                [Math]::Round($getTargetResourceResult.Size, 2) | Should Be 0.03
        
                Set-TargetResource -Ensure 'Absent' -Path $script:msiLocation -ProductId $script:packageId -Name ([String]::Empty)
                
                Test-PackageInstalled -Name $script:packageName | Should Be $false
            }

            It 'Should throw with incorrect product id' {
                $wrongPackageId = '{deadbeef-80c6-41e6-a1b9-8bdb8a050272}'

                { Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId $wrongPackageId -Name ([String]::Empty) } | Should Throw
            }

            It 'Should throw with incorrect name' {
                $wrongPackageName = 'WrongPackageName'

                { Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId ([String]::Empty) -Name $wrongPackageName } | Should Throw
            }

            It 'Should correctly install and remove a package from a HTTP URL' {
                $baseUrl = 'http://localhost:1242/'
                $msiUrl = "$baseUrl" + "package.msi"
                New-MockFileServer -FilePath $script:msiLocation

                # Test pipe connection as testing server readiness
                $pipe = New-Object -TypeName 'System.IO.Pipes.NamedPipeServerStream' -ArgumentList @( '\\.\pipe\dsctest1' )
                $pipe.WaitForConnection()
                $pipe.Dispose()

                { Set-TargetResource -Ensure 'Present' -Path $baseUrl -Name $script:packageName -ProductId $script:packageId } | Should Throw

                Set-TargetResource -Ensure 'Present' -Path $msiUrl -Name $script:packageName -ProductId $script:packageId
                Test-PackageInstalled -Name $script:packageName | Should Be $true

                Set-TargetResource -Ensure 'Absent' -Path $msiUrl -Name $script:packageName -ProductId $script:packageId
                Test-PackageInstalled -Name $script:packageName | Should Be $false

                $pipe = New-Object -TypeName 'System.IO.Pipes.NamedPipeClientStream' -ArgumentList @( '\\.\pipe\dsctest2' )
                $pipe.Connect()
                $pipe.Dispose()
            }

            It 'Should correctly install and remove a package from a HTTPS URL' -Skip:$script:skipHttpsTest {
                $baseUrl = 'https://localhost:1243/'
                $msiUrl = "$baseUrl" + "package.msi"
                New-MockFileServer -FilePath $script:msiLocation -Https

                # Test pipe connection as testing server readiness
                $pipe = New-Object -TypeName 'System.IO.Pipes.NamedPipeServerStream' -ArgumentList @( '\\.\pipe\dsctest1' )
                $pipe.WaitForConnection()
                $pipe.Dispose()

                { Set-TargetResource -Ensure 'Present' -Path $baseUrl -Name $script:packageName -ProductId $script:packageId } | Should Throw

                Set-TargetResource -Ensure 'Present' -Path $msiUrl -Name $script:packageName -ProductId $script:packageId
                Test-PackageInstalled -Name $script:packageName | Should Be $true

                Set-TargetResource -Ensure 'Absent' -Path $msiUrl -Name $script:packageName -ProductId $script:packageId
                Test-PackageInstalled -Name $script:packageName | Should Be $false

                $pipe = New-Object -TypeName 'System.IO.Pipes.NamedPipeClientStream' -ArgumentList @( '\\.\pipe\dsctest2' )
                $pipe.Connect()
                $pipe.Dispose()
            }

            It 'Should write to the specified log path' {
                $logPath = Join-Path -Path $script:testDirectoryPath -ChildPath 'TestMsiLog.txt'

                if (Test-Path -Path $logPath)
                {
                    Remove-Item -Path $logPath -Force
                }

                Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -Name $script:packageName -LogPath $logPath -ProductId ([string]::Empty)

                Test-Path -Path $logPath | Should Be $true 
                Get-Content -Path $logPath | Should Not Be $null
            }
        }

        Context 'Get-MsiTools' {
            It 'Should add MSI tools in the Microsoft.Windows.DesiredStateConfiguration.xPackageResource namespace' {
                $addTypeResult = @{ Namespace = 'Mock not called' }
                Mock -CommandName 'Add-Type' -MockWith { $addTypeResult['Namespace'] = $Namespace }

                $msiTools = Get-MsiTools
                
                if (([System.Management.Automation.PSTypeName]'Microsoft.Windows.DesiredStateConfiguration.xPackageResource.MsiTools').Type)
                {
                    Assert-MockCalled -CommandName 'Add-Type' -Times 0

                    $msiTools | Should Be ([System.Management.Automation.PSTypeName]'Microsoft.Windows.DesiredStateConfiguration.xPackageResource.MsiTools').Type
                }
                else
                {
                    Assert-MockCalled -CommandName 'Add-Type' -Times 1

                    $addTypeResult['Namespace'] | Should Be 'Microsoft.Windows.DesiredStateConfiguration.xPackageResource'
                    $msiTools | Should Be $null
                }
            }
        }
    }
}
