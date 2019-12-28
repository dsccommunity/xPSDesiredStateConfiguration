$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'xProcessSet'

try
{
    Import-Module -Name DscResource.Test -Force
}
catch [System.IO.FileNotFoundException]
{
    throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
}

$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dscResourceName `
    -ResourceType 'Mof' `
    -TestType 'Integration'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')

# Begin Testing
try
{
    Describe 'xProcessSet Integration Tests' {
        BeforeAll {
            $script:configurationFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'xProcessSet.config.ps1'

            # Setup test process paths.
            $script:notepadExePath = Resolve-Path -Path ([System.IO.Path]::Combine($env:SystemRoot, 'System32', 'notepad.exe'))
            $script:iexplorerExePath = Resolve-Path -Path ([System.IO.Path]::Combine( $env:ProgramFiles, 'internet explorer', 'iexplore.exe'))

            $script:processPaths = @( $script:notepadExePath, $script:iexplorerExePath)
        }

        AfterAll {
            foreach ($processPath in $script:processPaths)
            {
                Get-Process | Where-Object -FilterScript {$_.Path -like $processPath} | `
                    Stop-Process -Confirm:$false -Force
            }
        }

        Context 'Start two processes' {
            $configurationName = 'StartProcessSet'

            $processSetParameters = @{
                ProcessPaths = $script:processPaths
                Ensure = 'Present'
            }

            foreach ($processPath in $processSetParameters.ProcessPaths)
            {
                $processName = [System.IO.Path]::GetFileNameWithoutExtension($processPath)
                $process = Get-Process -Name $processName -ErrorAction 'SilentlyContinue'

                if ($null -ne $process)
                {
                    $null = Stop-Process -Name $processName -ErrorAction 'SilentlyContinue' -Force

                    # May need to wait a moment for the correct state to populate
                    $millisecondsElapsed = 0
                    $startTime = Get-Date
                    while ($null -eq $process -and $millisecondsElapsed -lt 3000)
                    {
                        $process = Get-Process -Name $processName -ErrorAction 'SilentlyContinue'
                        $millisecondsElapsed = ((Get-Date) - $startTime).TotalMilliseconds
                    }
                }

                It "Should not have started process $processName before configuration" {
                    $process | Should -Be $null
                }
            }

            It 'Should compile and run configuration' {
                {
                    . $script:configurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @processSetParameters
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw
            }

            foreach ($processPath in $processSetParameters.ProcessPaths)
            {
                $processName = [System.IO.Path]::GetFileNameWithoutExtension($processPath)
                $process = Get-Process -Name $processName -ErrorAction 'SilentlyContinue'

                It "Should have started process $processName after configuration" {
                    $process | Should -Not -Be $null
                }
            }
        }

        Context 'Stop two processes' {
            $configurationName = 'StopProcessSet'

            $processSetParameters = @{
                ProcessPaths = $script:processPaths
                Ensure = 'Absent'
            }

            foreach ($processPath in $processSetParameters.ProcessPaths)
            {
                $processName = [System.IO.Path]::GetFileNameWithoutExtension($processPath)
                $process = Get-Process -Name $processName -ErrorAction 'SilentlyContinue'

                if ($null -eq $process)
                {
                    $null = Start-Process -FilePath $processPath -ErrorAction 'SilentlyContinue'

                    # May need to wait a moment for the correct state to populate
                    $millisecondsElapsed = 0
                    $startTime = Get-Date
                    while ($null -eq $process -and $millisecondsElapsed -lt 3000)
                    {
                        $process = Get-Process -Name $processName -ErrorAction 'SilentlyContinue'
                        $millisecondsElapsed = ((Get-Date) - $startTime).TotalMilliseconds
                    }
                }

                It "Should have started process $processName before configuration" {
                    $process | Should -Not -Be $null
                }
            }

            It 'Should compile and run configuration' {
                {
                    . $script:configurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @processSetParameters
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw
            }

            foreach ($processPath in $processSetParameters.ProcessPaths)
            {
                $processName = [System.IO.Path]::GetFileNameWithoutExtension($processPath)
                $process = Get-Process -Name $processName -ErrorAction 'SilentlyContinue'

                It "Should have stopped process $processName after configuration" {
                    $process | Should -Be $null
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
