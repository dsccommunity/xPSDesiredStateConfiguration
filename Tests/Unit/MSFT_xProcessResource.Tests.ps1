Import-Module -Name "$PSScriptRoot\..\CommonTestHelper.psm1"

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
            }

            AfterAll {
                Stop-ProcessByName $script:cmdProcessShortName

                if (Test-Path -Path $script:cmdProcessFullPath)
                {
                    Remove-Item -Path $script:cmdProcessFullPath -ErrorAction 'SilentlyContinue' -Force
                }
            }

            BeforeEach {
                Stop-ProcessByName -ProcessName $script:cmdProcessShortName
            }

            Context 'Get-TargetResource' {
                It 'Should return the correct properties' -Pending {
                    $processArguments = 'TestGetProperties'

                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments $processArguments

                    $getTargetResourceResult = Get-TargetResource -Path $script:cmdProcessFullPath -Arguments $processArguments
                    $getTargetResourceProperties = @( 'VirtualMemorySize', 'Arguments', 'Ensure', 'PagedMemorySize', 'Path', 'NonPagedMemorySize', 'HandleCount', 'ProcessId' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceProperties $getTargetResourceProperties

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
            }

            Context 'Set-TargetResource' {
                It 'Should start and stop a process with no arguments' -Pending  {
                    Test-TargetResource -Path $script:cmdProcessFullPath -Arguments '' | Should Be $false
 
                    Set-TargetResource -Path $script:cmdProcessFullPath -Arguments ''
 
                    Test-TargetResource -Path $script:cmdProcessFullPath -Arguments '' | Should Be $true
 
                    Set-TargetResource -Path $script:cmdProcessFullPath -Ensure 'Absent' -Arguments ''
 
                    Test-TargetResource -Path $script:cmdProcessFullPath -Arguments '' | Should Be $false
                }

                It 'Should have correct output with WhatIf is specified' -Pending {
                    $script = "MSFT_ProcessResource\Set-TargetResource -Path {0} -Whatif -Arguments ''" -f $script:cmdProcessFullPath
                    TestWhatif $script $script:cmdProcessFullPath

                    $script = "MSFT_ProcessResource\Set-TargetResource -Path {0} -Ensure Absent -Whatif -Arguments ''" -f $script:cmdProcessFullPath
                    TestWhatif $script $script:cmdProcessFullPath
                }

                It 'TestWhatifStop' -Pending {
                    Invoke-Remotely {
                        $exePath = $script:cmdProcessFullPath

                        if(MSFT_ProcessResource\Test-TargetResource -Path $exePath -Arguments '')
                        {
                            throw "before set, there should be no process"
                        }

                        MSFT_ProcessResource\Set-TargetResource -Path $exePath -Arguments ''

                        $script = "MSFT_ProcessResource\Set-TargetResource -Path {0} -Ensure Absent -Whatif -Arguments ''" -f $exePath
                        TestWhatif $script $exePath

                        $script = "MSFT_ProcessResource\Set-TargetResource -Path {0} -Whatif -Arguments ''" -f $exePath
                        TestWhatif $script $exePath
        
                        MSFT_ProcessResource\Set-TargetResource -Path $exePath -Ensure "Absent" -Arguments ''
                    }
                }

                <#
                    .Synopsis
                    tests input, output and error streams are hooked up as well as the working directory
                #>
                It 'TestStreamsAndWorkingDirectory' -Pending {
                    Invoke-Remotely {
                        $exePath = $script:cmdProcessFullPath
 
                        if(MSFT_ProcessResource\Test-TargetResource -Path $exePath -Arguments "")
                        {
                            throw "before set, there should be no process"
                        }
 
                        $errorPath="$PWD\TestStreamsError.txt"
                        $outputPath="$PWD\TestStreamsOutput.txt"
                        $inputPath="$PWD\TestStreamsInput.txt"

                        Remove-Item $errorPath -Force -ErrorAction SilentlyContinue
                        Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
 
            "ECHO Testing ProcessTest.exe `
            dir volumeSyntaxError:\ ` 
            set /p waitforinput=Press [y/n]?: " | out-file $inputPath -Encoding ascii
 
                        MSFT_ProcessResource\Set-TargetResource -Path $exePath -WorkingDirectory $processTestPath -StandardOutputPath $outputPath -StandardErrorPath $errorPath -StandardInputPath $inputPath -Arguments ""
 
                        if(!(TryForAWhile ([scriptblock]::create("(MSFT_ProcessResource\Get-TargetResource -Path $exePath -Arguments '').Ensure -eq 'Absent'"))))
                        {
                            throw "process did not terminate"
                        }

                        # Race condition exists for retrieving contents of the process error stream file
                        Start-Sleep -Seconds 2 

                        $errorFile=get-content $errorPath -Raw
                        $outputFile=get-content $outputPath -Raw

                        if((Get-Culture).Name -ieq 'en-us')
                        {
                            Assert ($errorFile.Contains("The filename, directory name, or volume label syntax is incorrect.")) "no stdErr string in file"
                            Assert ($outputFile.Contains("Press [y/n]?:")) "no stdOut string in file"
                            Assert ($outputFile.ToLower().Contains($processTestPath.ToLower())) "working directory: $processTestPath, not in output file"
                        }
                        else
                        {
                            Assert  ($errorFile.Length -gt 0) "no stdErr string in file"
                            Assert  ($outputFile.Length -gt 0) "no stdOut string in file"
                        }
                    }
                }

                It 'TestCannotWritePropertiesWithAbsent' -Pending {
                    Invoke-Remotely {
                        $exePath = $script:cmdProcessFullPath

                         foreach($writeProperty in "StandardOutputPath","StandardErrorPath","StandardInputPath","WorkingDirectory")
                         {
                            $args=@{Path=$exePath;Ensure="Absent";Arguments=""}
                            $null=$args.Add($writeProperty,"anything")
                            $thrown = $false
                            try
                            {
                                MSFT_ProcessResource\Set-TargetResource @args
                            }
                            catch
                            {
                                $thrown = $true
                            }
                            Assert $thrown ("{0} cannot be set when using Absent" -f $writeProperty)
                         }
                     }
                }

                It 'TestCannotUseInvalidPath' -Pending {
                    Invoke-Remotely {
                        $exePath = $script:cmdProcessFullPath
                        $relativePath = "..\ExistingFile.txt"
                        "something" > $relativePath

                        $nonExistingPath = "$processTestPath\IDoNotExist.Really.I.Do.Not"
                        del $nonExistingPath -ErrorAction SilentlyContinue  

                        foreach($writeProperty in "StandardOutputPath","StandardErrorPath","StandardInputPath","WorkingDirectory")
                        {
                            $args=@{Path=$exePath;Ensure="Present";Arguments=""}
                            $null=$args.Add($writeProperty,$relativePath)
                            $thrown = $false
                            try
                            {
                                MSFT_ProcessResource\Set-TargetResource @args
                            }
                            catch
                            {
                                $thrown = $true
                            }
                            Assert $thrown ("{0} cannot be set to relative path" -f $writeProperty)
                        }


                        foreach($writeProperty in "StandardInputPath","WorkingDirectory")
                        {
                            $args=@{Path=$exePath;Ensure="Present";Arguments=""}
                            $args[$writeProperty] = $nonExistingPath
                            $thrown = $false
                            try
                            {
                                MSFT_ProcessResource\Set-TargetResource @args
                            }
                            catch
                            {
                                $thrown = $true
                            }
                            Assert $thrown ("{0} cannot be set to nonexisting path" -f $writeProperty)
                        }

                        foreach($writeProperty in "StandardOutputPath","StandardErrorPath")
                        {
                            # Paths that need not exist so no exception should be thrown
                            $args=@{Path=$exePath;Ensure="Present";Arguments=""}
                            $null=$args.Add($writeProperty,$nonExistingPath)
                            MSFT_ProcessResource\Set-TargetResource @args
                            get-process ProcessTest | stop-process
                            del $nonExistingPath -ErrorAction SilentlyContinue
                        }
                    }
                }

                It 'TestGetWmiObject' -Pending {
                    Invoke-Remotely {
                        $exePath = $script:cmdProcessFullPath
                        MSFT_ProcessResource\Set-TargetResource $exePath -Arguments ""
                        MSFT_ProcessResource\Set-TargetResource $exePath -Arguments "abc"
                        $r=@(GetWin32_Process $exePath -useWmiObjectCount 0)
                        AssertEquals $r.Count 1 "get-wmiobject with filter"
                        $a=@(GetWin32_Process $exePath -useWmiObjectCount 5)
                        AssertEquals $a.Count 1 "through get-process"
                        MSFT_ProcessResource\Set-TargetResource $exePath -Ensure Absent -Arguments ""
                    }
                }
            }

            Context 'Test-TargetResource' {
                It 'TestTestWithDirectoryArguments' -Pending {
                    Invoke-Remotely {
                        $exePath = $script:cmdProcessFullPath
                        $exists = MSFT_ProcessResource\Test-TargetResource $exePath -WorkingDirectory "something" -StandardOutputPath "something" `
                         -StandardErrorPath "something" -StandardInputPath "something" -Arguments ""
                        Assert !$exists "there should be no process"
                    }
                }
            }

        
    
 
        <#
            SPLIT into 3

            .Synopsis
            Tests a process with an argument.
            .DESCRIPTION
            - Starts a process with an argument
            - Ensures Test with "" as Arguments is false
            - Ensures Test with the wrong arguments is false
            - Ensures Test with no Arguments key is true
            - Ensures Test with the right Arguments key is true
            - Ensures Get with no arguments key is 1 Present
            - Ensures Get with "" as Arguments is 1 Absent

            - Starts process with no arguments
            - Ensures Get with no arguments key is 2
            - Ensures Get with null arguments is 1 Present with no Arguments
            - Ensures Get with argument is 1 Present with the Arguments
            - Set All process to be absent
            - Ensure none are left
        #>
        It 'TestGetSetProcessResourceWithArguments' -Pending {
            Invoke-Remotely {
                $exePath = $script:cmdProcessFullPath
 
                if(MSFT_ProcessResource\Test-TargetResource -Path $exePath -Arguments "")
                {
                    throw "before set, there should be no process"
                }
 
                MSFT_ProcessResource\Set-TargetResource -Path $exePath -Arguments "TestGetSetProcessResourceWithArguments"
 
                if(MSFT_ProcessResource\Test-TargetResource -Path $exePath -Arguments "")
                {
                    throw "after set, cannot find process with no arguments"
                }
 
                if(MSFT_ProcessResource\Test-TargetResource -Path $exePath -Arguments "NotTheOriginalArguments")
                {
                    throw "after set, cannot find process with arguments that were not the ones we set"
                }
 
                if(!(MSFT_ProcessResource\Test-TargetResource -Path $exePath -Arguments "TestGetSetProcessResourceWithArguments"))
                {
                    throw "after set, there should be a process if we specify arguments"
                }
 
                $processes = @(MSFT_ProcessResource\Get-TargetResource -Path $exePath -Arguments "")
 
                if($processes.Count -ne 1 -or $processes[0].Ensure -ne 'Absent')
                {
                    throw "there should be no process without arguments"
                }
 
                MSFT_ProcessResource\Set-TargetResource -Path $exePath -Arguments ""
 
                $processes = @(MSFT_ProcessResource\Get-TargetResource -Path $exePath -Arguments "")
                if($processes.Count -ne 1 -or $processes[0].Ensure -ne 'Present')
                {
                    throw "there should be only one process present with no argument"
                }
 
                if($processes[0].Arguments.length -ne 0)
                {
                    throw "there should no arguments in the process"
                }
 
                $processes = @(MSFT_ProcessResource\Get-TargetResource -Path $exePath -Arguments "TestGetSetProcessResourceWithArguments")
        
                if($processes.Count -ne 1 -or $processes[0].Ensure -ne 'Present')
                {
                    throw "there should be only one process present with TestGetSetProcessResourceWithArguments as argument"
                }
 
                if($processes[0].Arguments -ne 'TestGetSetProcessResourceWithArguments')
                {
                    throw "the argument should be TestGetSetProcessResourceWithArguments"
                }
 
                MSFT_ProcessResource\Set-TargetResource -Path $exePath -Ensure Absent -Arguments ""
 
                if(MSFT_ProcessResource\Test-TargetResource -Path $exePath -Arguments "")
                {
                    throw "after set absent, there should be no process"
                }
            }
        }

        Context 'WQLEscape' {
            It 'TestWQLEscape' -Pending {
                WQLEscape "a'`"\b" | Should Be "a\'\`"\\b"
            }
        }
 
        Context 'Get-ProcessArgumentsFromCommandLine' {
            It 'TestGetProcessArgumentsFromCommandLine' -Pending {
                $testCases=(("c    a   ","a"),('"c b d" e  ',"e"),("    a b","b"), (" abc ",""))
                foreach($testCase in $testCases)
                {
                    $test=$testCase[0]
                    $expected=$testCase[1]
                    $actual = GetProcessArgumentsFromCommandLine $test

                    $actual | Should Be $expected
                }
            }
        }

        

        
    
        

        #
        # Tests for Get-DomainAndUserName function.
        #
        Context 'Get-DomainAndUserName' {
            It 'TestDomainUserNameParseAt' -Pending {
                Invoke-Remotely {
                    $Domain, $UserName = Get-DomainAndUserName ([System.Management.Automation.PSCredential]::new( 
                        "user@domain", 
                        ("dummy" | ConvertTo-SecureString -asPlainText -Force) 
                    ) )
                    Assert ($Domain -eq "domain")  "wrong domain $Domain"
                    Assert ($UserName -eq "user") "wrong user $UserName"
                }
            }
    
            It 'TestDomainUserNameParseSlash' -Pending {
                Invoke-Remotely {
                    $Domain, $UserName = Get-DomainAndUserName ([System.Management.Automation.PSCredential]::new( 
                        "domain\user", 
                        ("dummy" | ConvertTo-SecureString -asPlainText -Force) 
                    ) )
                    Assert ($Domain -eq "domain")  "wrong domain $Domain"
                    Assert ($UserName -eq "user") "wrong user $UserName"
                }
            }
    
            It 'TestDomainUserNameParseImplicitDomain' -Pending {
                Invoke-Remotely {
                    $Domain, $UserName = Get-DomainAndUserName ([System.Management.Automation.PSCredential]::new( 
                        "localuser", 
                        ("dummy" | ConvertTo-SecureString -asPlainText -Force) 
                    ) )
                    Assert ($Domain -eq $env:COMPUTERNAME) "wrong domain $Domain"
                    Assert ($UserName -eq "localuser") "wrong user $UserName"
                }
            }
    
            Context 'TestDomainUserNameParseSlashFail.Context' {
    
                BeforeEach {
                    Invoke-Remotely {
                        $script:originalErrorActionPreference = $ErrorActionPreference
                        $global:ErrorActionPreference = 'Stop'
                    }
                }

                AfterEach {
                    Invoke-Remotely {
                        $global:ErrorActionPreference = $script:originalErrorActionPreference
                    }
                }

                It 'TestDomainUserNameParseSlashFail'  {
                    Invoke-Remotely {
                        try
                        {
                            $Domain, $UserName = Get-DomainAndUserName ([System.Management.Automation.PSCredential]::new( 
                                "domain\user\foo", 
                                ("dummy" | ConvertTo-SecureString -asPlainText -Force) 
                            ) )
                        } 
                        catch 
                        {
                            $exceptionThrown = $true
                            Assert ($_.Exception -is [System.ArgumentException]) "Exception of type $($_.Exception.GetType().ToString()) was not expected"
                        }
                        Assert ($exceptionThrown) "no exception thrown"
                    }
                }
    
                It 'TestDomainUserNameParseAtFail'  {
                    Invoke-Remotely {
                        try
                        {
                            $Domain, $UserName = Get-DomainAndUserName ([System.Management.Automation.PSCredential]::new( 
                                "domain@user@foo", 
                                ("dummy" | ConvertTo-SecureString -asPlainText -Force) 
                            ) )
                        } 
                        catch 
                        {
                            $exceptionThrown = $true
                            Assert ($_.Exception -is [System.ArgumentException]) "Exception of type $($_.Exception.GetType().ToString()) was not expected"
                        }
                        Assert ($exceptionThrown) "no exception thrown"
                        }
                    }
                }
            }
        }
    }
}
finally
{
    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
}
