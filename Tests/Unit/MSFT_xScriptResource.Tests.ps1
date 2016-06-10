# All tests with credentials will be skipped

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xScriptResource' `
    -TestType Unit

InModuleScope 'MSFT_xScriptResource' {
    Describe 'xScript Unit Tests' {
        BeforeAll {
            Import-Module "$PSScriptRoot\..\CommonTestHelper.psm1"

            $script:skipAllCredentialTests = $true

            $script:originalErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'
        }

        AfterAll {
            $ErrorActionPreference = $script:originalErrorActionPreference
        }
    
        It 'Get-TargetResource without credential' {
            $getScript = "@{ExecutionPolicy = Get-ExecutionPolicy; Date = Get-Date }"
            $setScript = "fakeSetScript"
            $testScript = "fakeTestScript"

            $getTargetResourceResultProperties = @('ExecutionPolicy', 'Date')
                 
            $getTargetResourceResult = Get-TargetResource -GetScript $getScript -SetScript $setScript -TestScript $testScript

            Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargetResourceResultProperties
        }
    
        It 'Get-TargetResource with credential' -Skip:$script:skipAllCredentialTests {
            $credential = $null

            $getScript = "@{ExecutionPolicy = Get-ExecutionPolicy; Date = Get-Date }"
            $setScript = "fakeSetScript"
            $testScript = "fakeTestScript"

            $getTargetResourceResultProperties = @('ExecutionPolicy', 'Date')
                 
            $getTargetResourceResult = Get-TargetResource -GetScript $getScript -SetScript $setScript -TestScript $testScript -Credential $credential

            Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargetResourceResultProperties
        }

        It 'Get-TargetResource with invalid result format from Get-Script' {
            $getScript = "'$true'"
            $setScript = "fakeSetScript"
            $testScript = "fakeTestScript"

            $getTargetResourceResultProperties = @('ExecutionPolicy', 'Date')
                 
            { Get-TargetResource -GetScript $getScript -SetScript $setScript -TestScript $testScript } | Should Throw
        }
    
        It 'Get-TargetResource with invalid command in Get-Script' {
            $getScript = "NonexistentCommand"
            $setScript = "fakeSetScript"
            $testScript = "fakeTestScript"

            $getTargetResourceResultProperties = @('ExecutionPolicy', 'Date')
                 
            { Get-TargetResource -GetScript $getScript -SetScript $setScript -TestScript $testScript } | Should Throw
        }

        It 'Set-TargetResource without credential' {
            $getScript = "fakeGetScript"
            $setScript = "'Executing Set-Script...'"
            $testScript = "fakeTestScript"

            $getTargetResourceResultProperties = @('ExecutionPolicy', 'Date')
                 
            { Set-TargetResource -GetScript $getScript -SetScript $setScript -TestScript $testScript } | Should Not Throw
        }

        It 'Set-TargetResource with credential' -Skip:$script:skipAllCredentialTests {
            $credential = $null

            $getScript = "fakeGetScript"
            $setScript = "'Executing Set-Script...'"
            $testScript = "fakeTestScript"

            $getTargetResourceResultProperties = @('ExecutionPolicy', 'Date')
                 
            { Set-TargetResource -GetScript $getScript -SetScript $setScript -TestScript $testScript -Credential $credential } | Should Not Throw
        }

        It 'Set-TargetResource with invalid command in Set-Script' {
            $getScript = "fakeGetScript"
            $setScript = "NonexistentCommand"
            $testScript = "fakeTestScript"

            $getTargetResourceResultProperties = @('ExecutionPolicy', 'Date')
                 
            { Set-TargetResource -GetScript $getScript -SetScript $setScript -TestScript $testScript } | Should Throw
        }

        It 'Test-TargetResource without credential' {
            $getScript = "fakeGetScript"
            $setScript = "fakeSetScript"
            $testScript = "'$true'"

            $testTargetResourceResult = Test-TargetResource -GetScript $getScript -SetScript $setScript -TestScript $testScript

            $testTargetResourceResult | Should Be $true
        }

        It 'Test-TargetResource with credential' -Skip:$script:skipAllCredentialTests {
            $credential = $null

            $getScript = "fakeGetScript"
            $setScript = "fakeSetScript"
            $testScript = "'$true'"

            $testTargetResourceResult = Test-TargetResource -GetScript $getScript -SetScript $setScript -TestScript $testScript -Credential $credential

            $testTargetResourceResult | Should Be $true
        }

        It 'Test-TargetResource with invalid command in Test-Script' {
            $getScript = "fakeGetScript"
            $setScript = "fakeSetScript"
            $testScript = "NonexistentCommand"

            { Test-TargetResource -GetScript $getScript -SetScript $setScript -TestScript $testScript } | Should Throw
        }
    }
}
