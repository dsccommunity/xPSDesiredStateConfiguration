# To run these tests, the currently logged on user must have rights to create a user
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xUserResource'

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
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\DSC_xUserResource.TestHelper.psm1')
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
        Describe 'xUserResource Unit Tests' {
            BeforeAll {
                # Used to skip the Nano server tests for the time being since they are not working on AppVeyor

                $script:skipMe = $true

                $script:existingUserName = 'TestUserName12345'
                $script:existingUserPassword = 'StrongOne7.'
                $script:existingDescription = 'Some Description'
                $script:existingSecurePassword = ConvertTo-SecureString $script:existingUserPassword -AsPlainText -Force
                $script:existingTestCredential = New-Object PSCredential ($script:existingUserName, $script:existingSecurePassword)

                New-User -Credential $script:existingTestCredential -Description $script:existingDescription

                $script:newUserName1 = 'NewTestUserName12345'
                $script:newUserPassword1 = 'NewStrongOne123.'
                $script:newFullName1 = 'Fullname1'
                $script:newUserDescription1 = 'New Description1'
                $script:newSecurePassword1 = ConvertTo-SecureString $script:newUserPassword1 -AsPlainText -Force
                $script:newCredential1 = New-Object PSCredential ($script:newUserName1, $script:newSecurePassword1)

                $script:newUserName2 = 'newUser1234'
                $script:newPassword2 = 'ThisIsAStrongPassword543!'
                $script:newFullName2 = 'Fullname2'
                $script:newUserDescription2 = 'New Description2'
                $script:newSecurePassword2 = ConvertTo-SecureString $script:newPassword2 -AsPlainText -Force
                $script:newCredential2 = New-Object PSCredential ($script:newUserName2, $script:newSecurePassword2)
            }

            AfterAll {
                Remove-User -UserName $script:existingUserName
            }

            Describe 'xUserResource/Get-TargetResource' {
                Context 'Tests on FullSKU' {
                    Mock -CommandName Test-IsNanoServer -MockWith { return $false }

                    It 'Should return the user as Present' {
                        $getTargetResourceResult = Get-TargetResource $script:existingUserName

                        $getTargetResourceResult['UserName']                | Should -Be $script:existingUserName
                        $getTargetResourceResult['Ensure']                  | Should -Be 'Present'
                        $getTargetResourceResult['Description']             | Should -Be $script:existingDescription
                        $getTargetResourceResult['PasswordChangeRequired']  | Should -Be $null
                    }

                    It 'Should return the user as Absent' {
                        $getTargetResourceResult = Get-TargetResource 'NotAUserName'

                        $getTargetResourceResult['UserName']                | Should -Be 'NotAUserName'
                        $getTargetResourceResult['Ensure']                  | Should -Be 'Absent'
                    }
                }

                Context 'Tests on Nano Server' {
                    Mock -CommandName Test-IsNanoServer -MockWith { return $true }

                    It 'Should return the user as Present on Nano Server' -Skip:$script:skipMe {
                        $getTargetResourceResult = Get-TargetResource $script:existingUserName

                        $getTargetResourceResult['UserName']                | Should -Be $script:existingUserName
                        $getTargetResourceResult['Ensure']                  | Should -Be 'Present'
                        $getTargetResourceResult['Description']             | Should -Be $script:existingDescription
                        $getTargetResourceResult['PasswordChangeRequired']  | Should -Be $null
                    }

                    It 'Should return the user as Absent' -Skip:$script:skipMe {
                        $getTargetResourceResult = Get-TargetResource 'NotAUserName'

                        $getTargetResourceResult['UserName']                | Should -Be 'NotAUserName'
                        $getTargetResourceResult['Ensure']                  | Should -Be 'Absent'
                    }
                }
            }

            Describe 'xUserResource/Set-TargetResource' {
                Context 'Tests on FullSKU' {
                    BeforeAll {
                        Remove-User -UserName $script:newUserName1
                        Remove-User -UserName $script:newUserName2
                    }

                    Mock -CommandName Test-IsNanoServer -MockWith { return $false }
                    #Mock -CommandName New-Object

                    New-User -Credential $script:newCredential1 -Description $script:newUserDescription1

                    It 'Should remove the user' {
                        Test-User -UserName $script:newUserName1 | Should -BeTrue
                        Set-TargetResource -UserName $script:newUserName1 -Ensure 'Absent'
                        Test-User -UserName $script:newUserName1 | Should -BeFalse
                    }

                    It 'Should add the new user' {
                        Set-TargetResource -UserName $script:newUserName2 -Password $script:newCredential2 -Ensure 'Present'
                        Test-User -UserName $script:newUserName2 | Should -BeTrue
                    }

                    It 'Should rename the user' {
                        Test-User -UserName $script:newUserName1 | Should -BeFalse
                        Set-TargetResource -UserName $script:newUserName2 `
                                            -NewName $script:newUserName1
                        Test-User -UserName $script:newUserName1 | Should -BeTrue
                    }

                    It 'Should rename the user again' {
                        Test-User -UserName $script:newUserName2 | Should -BeFalse
                        Set-TargetResource -UserName $script:newUserName1 `
                                            -NewName $script:newUserName2
                        Test-User -UserName $script:newUserName2 | Should -BeTrue
                    }

                    It 'Should update the user' {
                        $disabled = $false
                        $passwordNeverExpires = $true
                        $passwordChangeRequired = $false
                        $passwordChangeNotAllowed = $true

                        Set-TargetResource -UserName $script:newUserName2 `
                                            -Password $script:newCredential2 `
                                            -Ensure 'Present' `
                                            -FullName $script:newFullName1 `
                                            -Description $script:newUserDescription1 `
                                            -Disabled $disabled `
                                            -PasswordNeverExpires $passwordNeverExpires `
                                            -PasswordChangeRequired $passwordChangeRequired `
                                            -PasswordChangeNotAllowed $passwordChangeNotAllowed

                        Test-User -UserName $script:newUserName2 | Should -BeTrue
                        $testTargetResourceResult1 =
                                Test-TargetResource -UserName $script:newUserName2 `
                                                    -Password $script:newCredential2 `
                                                    -Ensure 'Present' `
                                                    -FullName $script:newFullName1 `
                                                    -Description $script:newUserDescription1 `
                                                    -Disabled $disabled `
                                                    -PasswordNeverExpires $passwordNeverExpires `
                                                    -PasswordChangeNotAllowed $passwordChangeNotAllowed
                        $testTargetResourceResult1 | Should -BeTrue
                    }

                    It 'Should update the user again with different values' {
                        $disabled = $false
                        $passwordNeverExpires = $false
                        $passwordChangeRequired = $true
                        $passwordChangeNotAllowed = $false

                        Set-TargetResource -UserName $script:newUserName2 `
                                            -Password $script:newCredential1 `
                                            -Ensure 'Present' `
                                            -FullName $script:newFullName2 `
                                            -Description $script:newUserDescription2 `
                                            -Disabled $disabled `
                                            -PasswordNeverExpires $passwordNeverExpires `
                                            -PasswordChangeRequired $passwordChangeRequired `
                                            -PasswordChangeNotAllowed $passwordChangeNotAllowed

                        Test-User -UserName $script:newUserName2 | Should -BeTrue
                        $testTargetResourceResult2 =
                                Test-TargetResource -UserName $script:newUserName2 `
                                                    -Password $script:newCredential1 `
                                                    -Ensure 'Present' `
                                                    -FullName $script:newFullName2 `
                                                    -Description $script:newUserDescription2 `
                                                    -Disabled $disabled `
                                                    -PasswordNeverExpires $passwordNeverExpires `
                                                    -PasswordChangeNotAllowed $passwordChangeNotAllowed
                        $testTargetResourceResult2 | Should -BeTrue
                    }
                }

                Context 'Tests on Nano Server' {
                    Mock -CommandName Test-IsNanoServer -MockWith { return $true }
                    Mock -CommandName Test-CredentialsValidOnNanoServer { return $true }

                    try
                    {
                        New-User -Credential $script:newCredential1 -Description $script:newUserDescription1

                        It 'Should remove the user' -Skip:$script:skipMe {
                            Test-User -UserName $script:newUserName1 | Should -BeTrue
                            Set-TargetResource -UserName $script:newUserName1 -Ensure 'Absent'
                            Test-User -UserName $script:newUserName1 | Should -BeFalse
                        }

                        It 'Should add the new user' -Skip:$script:skipMe {
                            Set-TargetResource -UserName $script:newUserName2 -Password $script:newCredential2 -Ensure 'Present'
                            Test-User -UserName $script:newUserName2 | Should -BeTrue
                        }

                        It 'Should rename the user' -Skip:$script:skipMe {
                            Test-User -UserName $script:newUserName1 | Should -BeFalse
                            Set-TargetResource -UserName $script:newUserName2 `
                                                -NewName $script:newUserName1
                            Test-User -UserName $script:newUserName1 | Should -BeTrue
                        }

                        It 'Should rename the user again' -Skip:$script:skipMe {
                            Test-User -UserName $script:newUserName2 | Should -BeFalse
                            Set-TargetResource -UserName $script:newUserName1 `
                                                -NewName $script:newUserName2
                            Test-User -UserName $script:newUserName2 | Should -BeTrue
                        }

                        It 'Should update the user' -Skip:$script:skipMe {
                            $disabled = $false
                            $passwordNeverExpires = $true
                            $passwordChangeRequired = $false
                            $passwordChangeNotAllowed = $true

                            Set-TargetResource -UserName $script:newUserName2 `
                                                -Password $script:newCredential2 `
                                                -Ensure 'Present' `
                                                -FullName $script:newFullName1 `
                                                -Description $script:newUserDescription1 `
                                                -Disabled $disabled `
                                                -PasswordNeverExpires $passwordNeverExpires `
                                                -PasswordChangeRequired $passwordChangeRequired `
                                                -PasswordChangeNotAllowed $passwordChangeNotAllowed

                            Test-User -UserName $script:newUserName2 | Should -BeTrue
                            $testTargetResourceResult1 =
                                    Test-TargetResource -UserName $script:newUserName2 `
                                                        -Password $script:newCredential2 `
                                                        -Ensure 'Present' `
                                                        -FullName $script:newFullName1 `
                                                        -Description $script:newUserDescription1 `
                                                        -Disabled $disabled `
                                                        -PasswordNeverExpires $passwordNeverExpires `
                                                        -PasswordChangeNotAllowed $passwordChangeNotAllowed
                            $testTargetResourceResult1 | Should -BeTrue
                        }
                        It 'Should update the user again with different values' -Skip:$script:skipMe {
                            $disabled = $false
                            $passwordNeverExpires = $false
                            $passwordChangeRequired = $true
                            $passwordChangeNotAllowed = $false

                            Set-TargetResource -UserName $script:newUserName2 `
                                                -Password $script:newCredential1 `
                                                -Ensure 'Present' `
                                                -FullName $script:newFullName2 `
                                                -Description $script:newUserDescription2 `
                                                -Disabled $disabled `
                                                -PasswordNeverExpires $passwordNeverExpires `
                                                -PasswordChangeRequired $passwordChangeRequired `
                                                -PasswordChangeNotAllowed $passwordChangeNotAllowed

                            Test-User -UserName $script:newUserName2 | Should -BeTrue
                            $testTargetResourceResult2 =
                                    Test-TargetResource -UserName $script:newUserName2 `
                                                        -Password $script:newCredential1 `
                                                        -Ensure 'Present' `
                                                        -FullName $script:newFullName2 `
                                                        -Description $script:newUserDescription2 `
                                                        -Disabled $disabled `
                                                        -PasswordNeverExpires $passwordNeverExpires `
                                                        -PasswordChangeNotAllowed $passwordChangeNotAllowed
                            $testTargetResourceResult2 | Should -BeTrue
                        }
                    }
                    finally
                    {
                        Remove-User -UserName $script:newUserName1
                        Remove-User -UserName $script:newUserName2
                    }
                }
            }

            Describe 'xUserResource/Test-TargetResource' {
                Context 'Tests on FullSKU' {
                    Mock -CommandName Test-IsNanoServer -MockWith { return $false }
                    $absentUserName = 'AbsentUserUserName123456789'

                    It 'Should return true when user Present and correct values' {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -Description $script:existingDescription `
                                                                        -Password $script:existingTestCredential `
                                                                        -Disabled $false `
                                                                        -PasswordNeverExpires $false `
                                                                        -PasswordChangeNotAllowed $false
                        $testTargetResourceResult | Should -BeTrue
                    }

                    It 'Should return true when user Absent and Ensure = Absent' {
                        $testTargetResourceResult = Test-TargetResource -UserName $absentUserName `
                                                                        -Ensure 'Absent'
                        $testTargetResourceResult | Should -BeTrue
                    }

                    It 'Should return false when user Absent and Ensure = Present' {
                        $testTargetResourceResult = Test-TargetResource -UserName $absentUserName `
                                                                        -Ensure 'Present'
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when user Present and Ensure = Absent' {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -Ensure 'Absent'
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when Password is wrong' {
                        $badPassword = 'WrongPassword'
                        $secureBadPassword = ConvertTo-SecureString $badPassword -AsPlainText -Force
                        $badTestCredential = New-Object PSCredential ($script:existingUserName, $secureBadPassword)

                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -Password $badTestCredential
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when user Present and wrong Description' {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -Description 'Wrong description'
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when FullName is incorrect' {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -FullName 'Wrong FullName'
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when Disabled is incorrect' {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -Disabled $true
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when PasswordNeverExpires is incorrect' {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -PasswordNeverExpires $true
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when PasswordChangeNotAllowed is incorrect' {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -PasswordChangeNotAllowed $true
                        $testTargetResourceResult | Should -BeFalse
                    }
                }

                Context 'Tests on Nano Server' {
                    Mock -CommandName Test-IsNanoServer -MockWith { return $true }

                    $absentUserName = 'AbsentUserUserName123456789'

                    It 'Should return true when user Present and correct values' -Skip:$script:skipMe {
                        Mock -CommandName Test-CredentialsValidOnNanoServer { return $true }

                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -Description $script:existingDescription `
                                                                        -Password $script:existingTestCredential `
                                                                        -Disabled $false `
                                                                        -PasswordNeverExpires $false `
                                                                        -PasswordChangeNotAllowed $false
                        $testTargetResourceResult | Should -BeTrue
                    }

                    It 'Should return true when user Absent and Ensure = Absent' -Skip:$script:skipMe {
                        $testTargetResourceResult = Test-TargetResource -UserName $absentUserName `
                                                                        -Ensure 'Absent'
                        $testTargetResourceResult | Should -BeTrue
                    }

                    It 'Should return false when user Absent and Ensure = Present' -Skip:$script:skipMe {
                        $testTargetResourceResult = Test-TargetResource -UserName $absentUserName `
                                                                        -Ensure 'Present'
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when user Present and Ensure = Absent' -Skip:$script:skipMe {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -Ensure 'Absent'
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when Password is wrong' -Skip:$script:skipMe {
                        Mock -CommandName Test-CredentialsValidOnNanoServer { return $false }

                        $badPassword = 'WrongPassword'
                        $secureBadPassword = ConvertTo-SecureString $badPassword -AsPlainText -Force
                        $badTestCredential = New-Object PSCredential ($script:existingUserName, $secureBadPassword)

                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -Password $badTestCredential
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when user Present and wrong Description' -Skip:$script:skipMe {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -Description 'Wrong description'
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when FullName is incorrect' -Skip:$script:skipMe {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -FullName 'Wrong FullName'
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when Disabled is incorrect' -Skip:$script:skipMe {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -Disabled $true
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when PasswordNeverExpires is incorrect' -Skip:$script:skipMe {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -PasswordNeverExpires $true
                        $testTargetResourceResult | Should -BeFalse
                    }

                    It 'Should return false when PasswordChangeNotAllowed is incorrect' -Skip:$script:skipMe {
                        $testTargetResourceResult = Test-TargetResource -UserName $script:existingUserName `
                                                                        -PasswordChangeNotAllowed $true
                        $testTargetResourceResult | Should -BeFalse
                    }
                }
            }

            Describe 'xUserResource/Assert-UserNameValid' {
                It 'Should not throw when username contains all valid chars' {
                    { Assert-UserNameValid -UserName 'abc123456!f_t-l098s' } | Should -Not -Throw
                }

                It 'Should throw InvalidArgumentError when username contains only whitespace and dots' {
                    $invalidName = ' . .. .     '
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                    $errorId = 'UserNameHasOnlyWhiteSpacesAndDots'
                    $errorMessage = "The name $invalidName cannot be used."
                    $exception = New-Object System.ArgumentException $errorMessage;
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
                    { Assert-UserNameValid -UserName $invalidName } | Should -Throw -ExpectedMessage $errorRecord
                }

                It 'Should throw InvalidArgumentError when username contains an invalid char' {
                    $invalidName = 'user|name'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                    $errorId = 'UserNameHasInvalidCharachter'
                    $errorMessage = "The name $invalidName cannot be used."
                    $exception = New-Object System.ArgumentException $errorMessage;
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
                    { Assert-UserNameValid -UserName $invalidName } | Should -Throw -ExpectedMessage $errorRecord
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
