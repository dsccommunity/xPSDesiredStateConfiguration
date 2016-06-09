#To run these tests, the currently logged on user must have rights to create a user
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xUserResource' `
    -TestType Unit

InModuleScope 'MSFT_xUserResource' {
    Describe 'xUser Unit Tests' {
        BeforeAll {
            Import-Module "$PSScriptRoot\CommonTestHelper.psm1"
            Import-Module "$PSScriptRoot\MSFT_xUserResource.TestHelper.psm1"
        }

        It 'Get-TargetResource user present' {
            $testUserName = "TestUserName12345"
            $testUserPassword = "StrongOne7."
            $testUserDescription = "Some Description"

            $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
            $testCredential = New-Object PSCredential ($testUserName, $secureTestPassword)

            New-User -Credential $testCredential -Description $testUserDescription

            try
            {
                $getTargetResourceResult = Get-TargetResource $testUserName

                $getTargerResourceResultProperties = @('UserName', 'Ensure', 'Description', 'Disabled', 'PasswordNeverExpires', 'PasswordChangeNotAllowed')

                Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargerResourceResultProperties

                $getTargetResourceResult["UserName"]                | Should Be $testUserName
                $getTargetResourceResult["Ensure"]                  | Should Be "Present"
                $getTargetResourceResult["Description"]             | Should Be $testUserDescription
                $getTargetResourceResult["PasswordChangeRequired"]  | Should Be $null
            }
            finally
            {
                Remove-User -UserName $testUserName
            }
        }

        It 'Get-TargetResource user absent' {
            $testUserName = "AbsentUserUserName123456789"

            $getTargetResourceResult = Get-TargetResource $testUserName

            $getTargerResourceResultProperties = @('UserName', 'Ensure')

            Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargerResourceResultProperties

            $getTargetResourceResult["UserName"]   | Should Be $TestUserName
            $getTargetResourceResult["Ensure"]     | Should Be "Absent"
        }

        It 'Test-TargetResource user present and correct description' {
            $testUserName = "TestUserName12345"
            $testUserPassword = "StrongOne7."
            $testUserDescription = "Some Description"

            $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
            $testCredential = New-Object PSCredential ($testUserName, $secureTestPassword)

            New-User -Credential $testCredential -Description $testUserDescription

            try
            {
                $testTargetResourceResult = Test-TargetResource $testUserName -Description $testUserDescription
                $testTargetResourceResult | Should Be $true
            }
            finally
            {
                Remove-User -UserName $testUserName
            }
        }

        It 'Test-TargetResource user present and wrong description' {
            $testUserName = "TestUserName12345"
            $testUserPassword = "StrongOne7."
            $testUserDescription = "Some Description"

            $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
            $testCredential = New-Object PSCredential ($testUserName, $secureTestPassword)

            New-User -Credential $testCredential -Description $testUserDescription

            try
            {
                $testTargetResourceResult = Test-TargetResource $testUserName -Description "Wrong description"
                $testTargetResourceResult | Should Be $false
            }
            finally
            {
                Remove-User -UserName $testUserName
            }
        }

        It 'Test-TargetResource user absent' {
            $absentUserName = "AbsentUserUserName123456789"
            $testTargetResourceResult = Test-TargetResource $absentUserName
            $testTargetResourceResult | Should Be $false
        }

        It 'Set-TargetResource user present and ensure present' {
            $testUserName = "TestUserName12345"
            $testUserPassword = "StrongOne7."
            $testUserDescription = "Some Description"

            $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
            $testCredential = New-Object PSCredential ($testUserName, $secureTestPassword)

            New-User -Credential $testCredential -Description $testUserDescription

            try
            {
                $setTargetResourceResult = Set-TargetResource $testUserName -Ensure Present
                Test-User -UserName $testUserName | Should Be $true
            }
            finally
            {
                Remove-User -UserName $testUserName
            }
        }

        It 'Set-TargetResource user present and ensure absent' {
            $testUserName = "TestUserName12345"
            $testUserPassword = "StrongOne7."
            $testUserDescription = "Some Description"

            $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
            $testCredential = New-Object PSCredential ($testUserName, $secureTestPassword)

            New-User -Credential $testCredential -Description $testUserDescription

            try
            {
                $setTargetResourceResult = Set-TargetResource $testUserName -Ensure Absent
                Test-User -UserName $testUserName | Should Be $false
            }
            finally
            {
                Remove-User -UserName $testUserName
            }
        }
    }
}
