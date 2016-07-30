Import-Module -Name "$PSScriptRoot\..\CommonTestHelper.psm1" -Force

$script:testEnvironment = Enter-DscResourceTestEnvironment `
    -DscResourceModuleName 'xPSDesiredStateConfiguration' `
    -DscResourceName 'MSFT_xProcessResource' `
    -TestType 'Unit'

try
{
    InModuleScope 'MSFT_xProcessResource' {
        Describe 'MSFT_xProcessResource Unit Tests' {
            BeforeAll {
                Import-Module -Name "$PSScriptRoot\MSFT_xProcessResource.TestHelper.psm1" -Force

                $script:cmdProcessShortName = 'ProcessTest'
                $script:cmdProcessFullName = 'ProcessTest.exe'
                $script:cmdProcessFullPath = "$env:winDir\system32\ProcessTest.exe"
                Copy-Item -Path "$env:winDir\system32\cmd.exe" -Destination $script:cmdProcessFullPath -ErrorAction 'SilentlyContinue' -Force

                $script:processTestFolder = Join-Path -Path (Get-Location) -ChildPath 'ProcessTestFolder'

                if (Test-Path -Path $script:processTestFolder)
                {
                    Remove-Item -Path $script:processTestFolder -Recurse -Force
                }

                New-Item -Path $script:processTestFolder -ItemType 'Directory' | Out-Null

                Push-Location -Path $script:processTestFolder
            }

            AfterAll {
                Stop-ProcessByName -ProcessName $script:cmdProcessShortName

                if (Test-Path -Path $script:cmdProcessFullPath)
                {
                    Remove-Item -Path $script:cmdProcessFullPath -ErrorAction 'SilentlyContinue' -Force
                }

                Pop-Location

                if (Test-Path -Path $script:processTestFolder)
                {
                    Remove-Item -Path $script:processTestFolder -Recurse -Force
                }
            }

            BeforeEach {
                Stop-ProcessByName -ProcessName $script:cmdProcessShortName
            }

            Context 'Get-TargetResource' {
                It 'Should return the correct properties for a process that is absent with Arguments' {
                    $processArguments = 'TestGetProperties'

                    $getTargetResourceResult = Get-TargetResource -Path $script:cmdProcessFullPath -Arguments $processArguments
                    $getTargetResourceProperties = @( 'Arguments', 'Ensure', 'Path' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargetResourceProperties

                    $getTargetResourceResult.Arguments | Should Be $processArguments
                    $getTargetResourceResult.Ensure | Should Be 'Absent'
                    $getTargetResourceResult.Path -icontains $script:cmdProcessFullPath | Should Be $true
                    $getTargetResourceResult.Count | Should Be 3
                } 

                It 'Should return the correct properties for a process that is absent without Arguments' {
                    $processArguments = ''

                    $getTargetResourceResult = Get-TargetResource -Path $script:cmdProcessFullPath -Arguments $processArguments
                    $getTargetResourceProperties = @( 'Arguments', 'Ensure', 'Path' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargetResourceProperties

                    $getTargetResourceResult.Arguments | Should Be $processArguments
                    $getTargetResourceResult.Ensure | Should Be 'Absent'
                    $getTargetResourceResult.Path -icontains $script:cmdProcessFullPath | Should Be $true
                    $getTargetResourceResult.Count | Should Be 3
                } 

                It 'Should return the correct properties for a process that is present with Arguments' {
                    $processArguments = 'TestGetProperties'

                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments $processArguments

                    $getTargetResourceResult = Get-TargetResource -Path $script:cmdProcessFullPath -Arguments $processArguments
                    $getTargetResourceProperties = @( 'VirtualMemorySize', 'Arguments', 'Ensure', 'PagedMemorySize', 'Path', 'NonPagedMemorySize', 'HandleCount', 'ProcessId' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargetResourceProperties

                    $getTargetResourceResult.VirtualMemorySize -le 0 | Should Be $false
                    $getTargetResourceResult.Arguments | Should Be $processArguments
                    $getTargetResourceResult.Ensure | Should Be 'Present'
                    $getTargetResourceResult.PagedMemorySize -le 0 | Should Be $false
                    $getTargetResourceResult.Path.IndexOf("ProcessTest.exe",[Stringcomparison]::OrdinalIgnoreCase) -le 0 | Should Be $false
                    $getTargetResourceResult.NonPagedMemorySize -le 0 | Should Be $false
                    $getTargetResourceResult.HandleCount -le 0 | Should Be $false
                    $getTargetResourceResult.ProcessId -le 0 | Should Be $false
                    $getTargetResourceResult.Count | Should Be 8
                }

                It 'Should return the correct properties for a process that is present without Arguments' {
                    $processArguments = ''

                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments $processArguments

                    $getTargetResourceResult = Get-TargetResource -Path $script:cmdProcessFullPath -Arguments $processArguments
                    $getTargetResourceProperties = @( 'VirtualMemorySize', 'Arguments', 'Ensure', 'PagedMemorySize', 'Path', 'NonPagedMemorySize', 'HandleCount', 'ProcessId' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargetResourceProperties

                    $getTargetResourceResult.VirtualMemorySize -le 0 | Should Be $false
                    $getTargetResourceResult.Arguments | Should Be $processArguments
                    $getTargetResourceResult.Ensure | Should Be 'Present'
                    $getTargetResourceResult.PagedMemorySize -le 0 | Should Be $false
                    $getTargetResourceResult.Path.IndexOf("ProcessTest.exe",[Stringcomparison]::OrdinalIgnoreCase) -le 0 | Should Be $false
                    $getTargetResourceResult.NonPagedMemorySize -le 0 | Should Be $false
                    $getTargetResourceResult.HandleCount -le 0 | Should Be $false
                    $getTargetResourceResult.ProcessId -le 0 | Should Be $false
                    $getTargetResourceResult.Count | Should Be 8
                }

                It 'Should return correct Ensure value based on Arguments parameter with multiple processes' {
                    $actualArguments = 'TestProcessResourceWithArguments'

                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments $actualArguments

                    $processes = @( Get-TargetResource -Path $script:cmdProcessFullPath -Arguments '')
 
                    $processes.Count | Should Be 1
                    $processes[0].Ensure | Should Be 'Absent'

                    $processes = @( Get-TargetResource -Path $script:cmdProcessFullPath -Arguments $actualArguments)
 
                    $processes.Count | Should Be 1
                    $processes[0].Ensure | Should Be 'Present'

                    $processes = @( Get-TargetResource -Path $script:cmdProcessFullPath -Arguments 'NotOrginalArguments')
 
                    $processes.Count | Should Be 1
                    $processes[0].Ensure | Should Be 'Absent'

                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments ''
 
                    $processes = @( Get-TargetResource -Path $script:cmdProcessFullPath -Arguments '')
 
                    $processes.Count | Should Be 1
                    $processes[0].Ensure | Should Be 'Present'
                    $processes[0].Arguments.Length | Should Be 0
 
                    $processes = @( Get-TargetResource -Path $script:cmdProcessFullPath -Arguments $actualArguments)
 
                    $processes.Count | Should Be 1
                    $processes[0].Ensure | Should Be 'Present'
                    $processes[0].Arguments | Should Be $actualArguments
                }
            }

            Context 'Set-TargetResource' {
                It 'Should start and stop a process with no arguments' {
                    Test-TargetResource -Path $script:cmdProcessFullPath -Arguments '' | Should Be $false
 
                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments ''
 
                    Test-TargetResource -Path $script:cmdProcessFullPath -Arguments '' | Should Be $true
 
                    Set-TargetResource -Path $script:cmdProcessFullPath -Ensure 'Absent' -Arguments ''
 
                    Test-TargetResource -Path $script:cmdProcessFullPath -Arguments '' | Should Be $false
                }

                It 'Should have correct output for absent process with WhatIf specified and default Ensure' {
                    $setTargetResourceParameters = @{
                        Path = $script:cmdProcessFullPath
                        Arguments = ''
                    }

                    $expectedWhatIfOutput = @( $LocalizedData.StartingProcessWhatif, $script:cmdProcessFullPath )

                    Test-SetTargetResourceWithWhatIf -Parameters $setTargetResourceParameters -ExpectedOutput $expectedWhatIfOutput

                    if ($setTargetResourceParameters.ContainsKey('WhatIf'))
                    {
                        $setTargetResourceParameters.Remove('WhatIf')
                    }

                    $testTargetResourceResult = Test-TargetResource @setTargetResourceParameters
                    $testTargetResourceResult | Should Be $false
                }

                It 'Should have no output for absent process with WhatIf specified and Ensure Absent' {
                    $setTargetResourceParameters = @{
                        Ensure = 'Absent'
                        Path = $script:cmdProcessFullPath
                        Arguments = ''
                    }

                    Test-SetTargetResourceWithWhatIf -Parameters $setTargetResourceParameters -ExpectedOutput ''
                }

                It 'Should have correct output for existing process with WhatIf specified and Ensure Absent' {
                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments ''

                    $setTargetResourceParameters = @{
                        Ensure = 'Absent'
                        Path = $script:cmdProcessFullPath
                        Arguments = ''
                    }

                    $expectedWhatIfOutput = @( $LocalizedData.StoppingProcessWhatif, $script:cmdProcessFullPath )

                    Test-SetTargetResourceWithWhatIf -Parameters $setTargetResourceParameters -ExpectedOutput $expectedWhatIfOutput

                    if ($setTargetResourceParameters.ContainsKey('WhatIf'))
                    {
                        $setTargetResourceParameters.Remove('WhatIf')
                    }

                    $testTargetResourceResult = Test-TargetResource @setTargetResourceParameters
                    $testTargetResourceResult | Should Be $false
                }

                It 'Should have no output for existing process with WhatIf specified and default Ensure' {
                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments ''

                    $setTargetResourceParameters = @{
                        Path = $script:cmdProcessFullPath
                        Arguments = ''
                    }

                    Test-SetTargetResourceWithWhatIf -Parameters $setTargetResourceParameters -ExpectedOutput ''
                }

                It 'Should provide correct error output to the specified error and output streams when using invalid input from the specified input stream' {
                    $errorPath = Join-Path -Path (Get-Location) -ChildPath 'TestStreamsError.txt'
                    $outputPath = Join-Path -Path (Get-Location) -ChildPath 'TestStreamsOutput.txt'
                    $inputPath = Join-Path -Path (Get-Location) -ChildPath 'TestStreamsInput.txt'

                    $workingDirectoryPath = Join-Path -Path (Get-Location) -ChildPath 'TestWorkingDirectory'

                    foreach ($path in @( $errorPath, $outputPath, $inputPath, $workingDirectoryPath ))
                    {
                        if (Test-Path -Path $path)
                        {
                            Remove-Item -Path $path -Recurse -Force
                        }
                    }

                    New-Item -Path $workingDirectoryPath -ItemType 'Directory' | Out-Null

                    $inputFileText = "ECHO Testing ProcessTest.exe `
                        dir volumeSyntaxError:\ ` 
                        set /p waitforinput=Press [y/n]?: "
 
                    Out-File -FilePath $inputPath -InputObject $inputFileText -Encoding 'ASCII'
 
                    Set-TargetResource -Path $script:cmdProcessFullPath -WorkingDirectory $workingDirectoryPath -StandardOutputPath $outputPath -StandardErrorPath $errorPath -StandardInputPath $inputPath -Arguments ''
 
                    Wait-ScriptBlockReturnTrue -ScriptBlock { (Get-TargetResource -Path $script:cmdProcessFullPath -Arguments '').Ensure -ieq 'Absent' } -TimeoutSeconds 10

                    Wait-ScriptBlockReturnTrue -ScriptBlock { Test-IsFileLocked -Path $errorPath } -TimeoutSeconds 2

                    $errorFileContent = Get-Content -Path $errorPath -Raw
                    $errorFileContent | Should Not Be $null

                    Wait-ScriptBlockReturnTrue -ScriptBlock { Test-IsFileLocked -Path $outputPath } -TimeoutSeconds 2

                    $outputFileContent = Get-Content -Path $outputPath -Raw
                    $outputFileContent | Should Not Be $null

                    if ((Get-Culture).Name -ieq 'en-us')
                    {
                        $errorFileContent.Contains('The filename, directory name, or volume label syntax is incorrect.') | Should Be $true
                        $outputFileContent.Contains('Press [y/n]?:') | Should Be $true
                        $outputFileContent.ToLower().Contains($workingDirectoryPath.ToLower()) | Should Be $true
                    }
                    else
                    {
                        $errorFileContent.Length -gt 0 | Should Be $true
                        $outputFileContent.Length -gt 0 | Should Be $true
                    }
                }

                It 'Should throw when trying to specify streams or working directory with Ensure Absent' {
                    $invalidPropertiesWithAbsent = @( 'StandardOutputPath', 'StandardErrorPath', 'StandardInputPath', 'WorkingDirectory' )

                    foreach ($invalidPropertyWithAbsent in $invalidPropertiesWithAbsent)
                    {
                        $setTargetResourceArguments = @{
                            Path = $script:cmdProcessFullPath
                            Ensure = 'Absent'
                            Arguments = ''
                            $invalidPropertyWithAbsent = 'Something'
                        }

                        { Set-TargetResource @setTargetResourceArguments } | Should Throw ($LocalizedData.ParameterShouldNotBeSpecified -f $invalidPropertyWithAbsent)
                    }
                }

                It 'Should throw when passing a relative path to stream or working directory parameters' {
                    $invalidRelativePath = '..\RelativePath'
                    $pathParameters = @( 'StandardOutputPath', 'StandardErrorPath', 'StandardInputPath', 'WorkingDirectory' )

                    foreach($pathParameter in $pathParameters)
                    {
                        $setTargetResourceParameters = @{
                            Path = $script:cmdProcessFullPath
                            Ensure = 'Present'
                            Arguments = ''
                            $pathParameter = $invalidRelativePath
                        }
                            
                        { Set-TargetResource @setTargetResourceParameters } | Should Throw $LocalizedData.PathShouldBeAbsolute
                    }
                }

                It 'Should throw when providing a nonexistent path for StandardInputPath or WorkingDirectory' {
                    $invalidNonexistentPath = Join-Path -Path (Get-Location) -ChildPath 'NonexistentPath'

                    if (Test-Path -Path $invalidNonexistentPath)
                    {
                        Remove-Item -Path $invalidNonexistentPath -Recurse -Force
                    }

                    $pathMustExistParameters = @( 'StandardInputPath', 'WorkingDirectory' )

                    foreach ($pathMustExistParameter in $pathMustExistParameters)
                    {
                        $setTargetResourceParameters = @{
                            Path = $script:cmdProcessFullPath
                            Ensure = 'Present'
                            Arguments = ''
                            $pathMustExistParameter = $invalidNonexistentPath
                        }

                        { Set-TargetResource @setTargetResourceParameters } | Should Throw $LocalizedData.PathShouldExist
                    }
                }

                It 'Should not throw when providing a nonexistent path for StandardOutputPath or StandardErrorPath' {
                    $invalidNonexistentPath = Join-Path -Path (Get-Location) -ChildPath 'NonexistentPath'

                    if (Test-Path -Path $invalidNonexistentPath)
                    {
                        Remove-Item -Path $invalidNonexistentPath -Recurse -Force
                    }

                    $pathNotNeedExistParameters = @( 'StandardOutputPath', 'StandardErrorPath' )

                    foreach ($pathNotNeedExistParameter in $pathNotNeedExistParameters)
                    {
                        $setTargetResourceParameters = @{
                            Path = $script:cmdProcessFullPath
                            Ensure = 'Present'
                            Arguments = ''
                            $pathNotNeedExistParameter = $invalidNonexistentPath
                        }

                        { Set-TargetResource @setTargetResourceParameters } | Should Not Throw
                    }
                }
            }

            Context 'Test-TargetResource' {
                It 'Should return correct value based on Arguments' {
                    $actualArguments = 'TestProcessResourceWithArguments'

                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments $actualArguments
 
                    Test-TargetResource -Path $script:cmdProcessFullPath -Arguments '' | Should Be $false
 
                    Test-TargetResource -Path $script:cmdProcessFullPath -Arguments 'NotTheOriginalArguments' | Should Be $false

                    Test-TargetResource -Path $script:cmdProcessFullPath -Arguments $actualArguments | Should Be $true
                }

                It 'Should return false for absent process with directory arguments' {
                    $testTargetResourceResult = Test-TargetResource `
                        -Path $script:cmdProcessFullPath `
                        -WorkingDirectory 'something' `
                        -StandardOutputPath 'something' `
                        -StandardErrorPath 'something' `
                        -StandardInputPath 'something' `
                        -Arguments ''
                        
                    $testTargetResourceResult | Should Be $false
                }

            }

            Context 'Get-Win32Process' {
                It 'Should only return one process when arguments were changed for that process' {
                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments ''
                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments 'abc'

                    $processes = @( Get-Win32Process -Path $script:cmdProcessFullPath -UseGetCimInstanceThreshold 0 )
                    $processes.Count | Should Be 1

                    $processes = @( Get-Win32Process -Path $script:cmdProcessFullPath -UseGetCimInstanceThreshold 5 )
                    $processes.Count | Should Be 1
                }
            }

            Context 'Get-ArgumentsFromCommandLineInput' {
                It 'Should retrieve expected arguments from command line input' {
                    $testCases = @( @{
                            CommandLineInput = "c    a   "
                            ExpectedArguments = "a"
                        },
                        @{
                            CommandLineInput = '"c b d" e  '
                            ExpectedArguments = "e"
                        },
                        @{
                            CommandLineInput = "    a b"
                            ExpectedArguments = "b"
                        },
                        @{
                            CommandLineInput = " abc "
                            ExpectedArguments = ""
                        }
                    )

                    foreach ($testCase in $testCases)
                    {
                        $commandLineInput = $testCase.CommandLineInput
                        $expectedArguments = $testCase.ExpectedArguments
                        $actualArguments = Get-ArgumentsFromCommandLineInput -CommandLineInput $commandLineInput

                        $actualArguments | Should Be $expectedArguments
                    }
                }
            }

            Context 'Split-Credential' {
                It 'Should return correct domain and username with @ seperator' {
                    $testUsername = 'user@domain'
                    $testPassword = ConvertTo-SecureString -String 'dummy' -AsPlainText -Force
                    $testCredential = New-Object -TypeName 'PSCredential' -ArgumentList @($testUsername, $testPassword)

                    $splitCredentialResult = Split-Credential -Credential $testCredential

                    $splitCredentialResult.Domain | Should Be 'domain'
                    $splitCredentialResult.Username | Should Be 'user'
                }
    
                It 'Should return correct domain and username with \ seperator' {
                    $testUsername = 'domain\user'
                    $testPassword = ConvertTo-SecureString -String 'dummy' -AsPlainText -Force
                    $testCredential = New-Object -TypeName 'PSCredential' -ArgumentList @($testUsername, $testPassword)

                    $splitCredentialResult = Split-Credential -Credential $testCredential

                    $splitCredentialResult.Domain | Should Be 'domain'
                    $splitCredentialResult.Username | Should Be 'user'
                }
    
                It 'Should return correct domain and username with a local user' {
                    $testUsername = 'localuser'
                    $testPassword = ConvertTo-SecureString -String 'dummy' -AsPlainText -Force
                    $testCredential = New-Object -TypeName 'PSCredential' -ArgumentList @($testUsername, $testPassword)

                    $splitCredentialResult = Split-Credential -Credential $testCredential

                    $splitCredentialResult.Username | Should Be 'localuser'
                }
    
                It 'Should throw when more than one \ in username' {
                    $testUsername = 'user\domain\foo'
                    $testPassword = ConvertTo-SecureString -String 'dummy' -AsPlainText -Force
                    $testCredential = New-Object -TypeName 'PSCredential' -ArgumentList @($testUsername, $testPassword)
                    
                    { $splitCredentialResult = Split-Credential -Credential $testCredential } | Should Throw
                }
    
                It 'Should throw when more than one @ in username' {
                    $testUsername = 'user@domain@foo'
                    $testPassword = ConvertTo-SecureString -String 'dummy' -AsPlainText -Force
                    $testCredential = New-Object -TypeName 'PSCredential' -ArgumentList @($testUsername, $testPassword)
                    
                    { $splitCredentialResult = Split-Credential -Credential $testCredential } | Should Throw
                }
            }
        }
    }
}
finally
{
    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
}
