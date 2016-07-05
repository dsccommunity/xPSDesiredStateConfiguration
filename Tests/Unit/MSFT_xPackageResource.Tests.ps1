$testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xPackageResource' `
    -TestType 'Unit'

InModuleScope 'MSFT_xPackageResource' {
    Describe 'MSFT_xPackageResource Unit Tests' {
        BeforeAll {
            Import-Module "$PSScriptRoot\..\CommonTestHelper.psm1" -Force
            Import-Module "$PSScriptRoot\MSFT_xPackageResource.TestHelper.psm1" -Force

            $testDirectoryPath = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_xPackageResourceTests'

            New-Item -Path $testDirectoryPath -ItemType 'Directory' | Out-Null

            $script:msiName = 'DSCSetupProject.msi'
            $script:msiLocation = Join-Path -Path $testDirectoryPath -ChildPath $script:msiName
            
            $script:packageName = 'DSCUnitTestPackage'
            $script:packageId = '{deadbeef-80c6-41e6-a1b9-8bdb8a05027f}'

            New-TestMsi -DestinationPath $script:msiLocation | Out-Null

            Clear-xPackageCache | Out-Null
        }

        BeforeEach {
            Clear-xPackageCache | Out-Null

            if (Test-PackageInstalled -Name $script:packageName)
            {
                Start-Process -FilePath 'msiexec.exe' -ArgumentList @("/x$PackageId", '/passive') -Wait | Out-Null
                Start-Sleep -Seconds 1 | Out-Null
            }
        
            if (Test-PackageInstalled -Name $script:packageName)
            {
                throw 'Test output will not be valid - package could not be removed.'
            }
        }

        AfterAll {
            Remove-Item -Path $testDirectoryPath -Recurse | Out-Null
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

            It 'Should return correct value when package is present' -Pending {
                Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId $script:packageId -Name ([string]::Empty)
            
                Clear-xPackageCache

                if (-not (Test-PackageInstalled -Name $script:packageName))
                {
                    throw 'Failed to install the package'
                }
        
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
            It 'Should correctly install and remove a package' -Pending {
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

            It 'Should throw with incorrect product id' -Pending {
                $wrongPackageId = '{deadbeef-80c6-41e6-a1b9-8bdb8a050272}'

                { Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId $wrongPackageId -Name ([String]::Empty) } | Should Throw
            }

            It 'Should throw with incorrect name' -Pending {
                $wrongPackageName = 'WrongPackageName'

                { Set-TargetResource -Ensure 'Present' -Path $script:msiLocation -ProductId ([String]::Empty) -Name $wrongPackageName } | Should Throw
            }

            It 'Should correctly install and remove a package from a URL' -Pending { #-Skip:(-not $script:shouldRun -or (-not (EnablePullServerTests)) -or (-not (RunOnServerSEDomainJoinedMachine)) -or (-not (IsWin8orAbove))) {
                Invoke-Remotely {
                    $baseUrl = "http://localhost:1242/"
                    $msiUrl = "$baseUrl" + "package.msi"
                    Serve-Binary $MsiLocation

                    # test pipe connection as testing server readiness
                    $pipe = New-Object -TypeName 'System.IO.Pipes.NamedPipeServerStream' -ArgumentList @( '\\.\pipe\dsctest1' )
                    $pipe.WaitForConnection()
                    $pipe.Dispose()

                    { Set-TargetResource -Ensure 'Present' -Path $baseUrl -Name $PackageName -ProductId $PackageId } | Should Throw

                    Set-TargetResource -Ensure 'Present' -Path $url -Name $PackageName -ProductId $PackageId -Verbose
                    if (-not (Is-NameInstalled $PackageName))
                    {
                        throw "Failed to install the package"
                    }

                    Set-TargetResource -Ensure 'Absent' -Path $url -Name $script:packageName -ProductId $script:packageId
                    Test-PackageInstalled -Name $script:packageName | Should Be $false

                    $pipe = New-Object -TypeName System.IO.Pipes.NamedPipeClientStream -ArgumentList @( '\\.\pipe\dsctest2' )
                    $pipe.Connect()
                    $pipe.Dispose()
                }
            }

            It 'TestHttpsMsiInstallAndRemoval' -Pending { # -Skip:(-not $script:shouldRun -or (-not (EnablePullServerTests)) -or (-not (RunOnServerSEDomainJoinedMachine)) -or (-not (IsWin8orAbove))) {
                Invoke-Remotely {
                    $baseUrl = "https://localhost:1243/"
                    $url = "$baseUrl" + "package.msi"
                    Serve-Binary $MsiLocation

                    # test pipe connection as testing server readiness
                    $pipe = New-Object System.IO.Pipes.NamedPipeServerStream("\\.\pipe\dsctest1")
                    $pipe.WaitForConnection()
                    $pipe.Dispose()

                    $error = $null
                    try
                    {
                        Set-TargetResource -Ensure "Present" -Path $baseUrl -Name $PackageName -ProductId $PackageId -Verbose
                    }
                    catch { $error = $_}

                    if (-not $error)
                    {
                        throw "Expected an error when trying to specify a non-msi file over HTTP"
                    }

                    Set-TargetResource -Ensure "Present" -Path $url -Name $PackageName -ProductId $PackageId -Verbose
                    if (-not (Is-NameInstalled $PackageName))
                    {
                        throw "Failed to install the package"
                    }

                    Set-TargetResource -Ensure "Absent" -Path $url -Name $PackageName -ProductId $PackageId -Verbose
                    if (Is-NameInstalled $PackageName)
                    {
                        throw "Failed to uninstall the package"
                    }

                    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream("\\.\pipe\dsctest2")
                    $pipe.Connect()
                    $pipe.Dispose()
                }
            }

            It 'TestMSILoggingFunctionality' -Pending {
                Invoke-Remotely {
                    param ($currentDir)
                    $logPath = "$currentDir\TestMsiLog.txt"
                    Set-TargetResource -Ensure "Present" -Path $MsiLocation -Name $PackageName -LogPath $logPath -Verbose -ProductId ([string]::Empty)
                    if(-not (Test-Path $logPath) -or -not (Get-Content $logPath))
                    {
                        throw "Log was not properly written by the MSI - provider likely did not redirect"
                    }
                } -ArgumentList $PSScriptRoot
            }
        }
    
    # TestCase TestLocalSetupExeInstall -tags @("DRT") {
        # $exePath = Get-SetupExe
        # $res = Test-TargetResource -Ensure "Present" -Path $exePath -Name $PackageName -Verbose
        # if($res)
        # {
            # throw "Erroneously believe EXE is installed when it is not"
        # }
        
        # $res = Test-TargetResource -Ensure "Absent" -Path $exePath -Name $PackageName -Verbose
        # if(-not $res)
        # {
            # throw "Erroneously believe EXE is installed when it is not"
        # }
        
        # $res = Test-TargetResource -Ensure "Present" -Path $exePath -ProductId $PackageId -Verbose
        # if($res)
        # {
            # throw "Erroneously believe EXE is installed when it is not when queried by ID"
        # }
        
        # $res = Test-TargetResource -Ensure "Absent" -Path $exePath -ProductId $PackageId -Verbose
        # if(-not $res)
        # {
            # throw "Erroneously believe EXE is installed when it is not when queried by ID"
        # }
        
        # $logPath = "$PSScriptRoot\TestLocalSetupExeInstall.log"
        # Set-TargetResource -Ensure "Present" -Path $exePath -ProductId $PackageId -Arguments "DUMMYFLAG=MYEXEVALUE" -LogPath $logPath -Verbose
        
        # $res = Test-TargetResource -Ensure "Present" -Path $exePath -Name $PackageName -Verbose
        # if(-not $res)
        # {
            # throw "Erroneously believe EXE is missing when it is not"
        # }
        
        # $res = Test-TargetResource -Ensure "Absent" -Path $exePath -Name $PackageName -Verbose
        # if($res)
        # {
            # throw "Erroneously believe EXE is missing when it is not"
        # }
        
        # $res = Test-TargetResource -Ensure "Present" -Path $exePath -ProductId $PackageId -Verbose
        # if(-not $res)
        # {
            # throw "Erroneously believe EXE is missing when it is not when queried by ID"
        # }
        
        # $res = Test-TargetResource -Ensure "Absent" -Path $exePath -ProductId $PackageId -Verbose
        # if($res)
        # {
            # throw "Erroneously believe EXE is missing when it is not when queried by ID"
        # }
        
        # $content = Get-Content $logPath
        # if(-not $content -or -not $content.Contains("DUMMYFLAG=MYEXEVALUE"))
        # {
            # throw "Process output not appropriately captured - the expected data was not present"
        # }
        
        # #Unit tests can be run on x86 Client SKU
        # $item = Get-Item -EA Ignore HKLM:\SOFTWARE\DSCTest
        # if(-not $item)
        # {
            # $item = Get-Item HKLM:\SOFTWARE\Wow6432Node\DSCTest
        # }
        
        # $debugEntry = $item.GetValue("DebugEntry")
        # if($debugEntry -ne "DUMMYFLAG=MYEXEVALUE")
        # {
            # throw "The registry key created by the package does not have the flag set appropriately. The provider likely did not pass the arguments correctly"
        # }
    # }
    
    # TestCase TestMSIOverUncPath -tags @("DRT") {
        # $share = Share-ScriptFolder
        # $shareName = $share.Name
        # $sharePath = "\\localhost\$shareName"
        # $uncMsiPath = Join-Path $sharePath $MsiName
        
        # $res = Test-TargetResource -Ensure "Present" -Path $uncMsiPath -Name $PackageName -Verbose
        # if($res)
        # {
            # throw "Erroneously belive package already exists when accessed over UNC"
        # }
        
        # $res = Test-TargetResource -Ensure "Absent" -Path $uncMsiPath -Name $PackageName -Verbose
        # if(-not $res)
        # {
            # throw "Erroneously belive package already exists when accessed over UNC (Ensure=Absent case)"
        # }
        
        # Set-TargetResource -Ensure "Present" -Path $uncMsiPath -Name $PackageName -Verbose
        # if(-not (Is-NameInstalled $PackageName))
        # {
            # throw "Failed to install the package"
        # }
        
        # $res = Test-TargetResource -Ensure "Present" -Path $uncMsiPath -Name $PackageName -Verbose
        # if(-not $res)
        # {
            # throw "Erroneously belive package is missing when accessed over UNC"
        # }
        
        # $res = Test-TargetResource -Ensure "Absent" -Path $uncMsiPath -Name $PackageName -Verbose
        # if($res)
        # {
            # throw "Erroneously belive package is missing when accessed over UNC (Ensure=Absent case)"
        # }
    # }

        Context 'Get-MsiTools' {
            It 'Uses Add-Type with a name that does not conflict with the original Package resource' -Pending {
                $hash = @{ Namespace = 'Mock not called' }
                Mock Add-Type { $hash['Namespace'] = $Namespace }
                $null = Get-MsiTools

                $hash['Namespace'] | Should Be 'Microsoft.Windows.DesiredStateConfiguration.xPackageResource'
            }
        }

        Context 'Get-RegistryValueIgnoreError' {
            It 'Should get values from HKLM' -Pending {
                $installValue = Get-RegistryValueIgnoreError 'LocalMachine' "SOFTWARE\Microsoft\Windows\CurrentVersion" "ProgramFilesDir" Registry64
                $installValue | should be $env:programfiles
            }

            It 'Should get values from HKCU' -Pending {
                $installValue = Get-RegistryValueIgnoreError 'CurrentUser' "Environment" "Temp" Registry64
                $installValue.length -gt 3 | should be $true
                $installValue | should match $env:username
                # comparing $installValue with $env:temp may fail if the username is longer than 8 characters
            }
        }
    }
}
