[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

Import-Module "$PSScriptRoot\..\..\DSCResource.Tests\TestHelper.psm1" -Force

Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xGroupResource' `
    -TestType Unit `
    | Out-Null

InModuleScope 'MSFT_xGroupResource' {
    Describe 'xGroup Unit Tests'  {

        BeforeAll {
            Import-Module "$PSScriptRoot\MSFT_xGroupResource.TestHelper.psm1" -Force
            Import-Module "$PSScriptRoot\..\CommonTestHelper.psm1" -Force

            $script:skipTestsWithCredentials = $true
        }

        Context 'Get-TargetResource' {
            It 'Should return hashtable with correct values when group has members' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    $getTargetResourceResult = Get-TargetResource -GroupName $testGroupName
                    $getTargetResourceResultProperties = @( 'GroupName', 'Ensure', 'Description', 'Members' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargerResourceResultProperties

                    $getTargetResourceResult['GroupName']       | Should Be $testGroupName
                    $getTargetResourceResult['Ensure']          | Should Be 'Present'
                    $getTargetResourceResult['Description']     | Should Be $testDescription
                    $getTargetResourceResult['Members'].Count   | Should Be 2
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return hashtable with correct values when group has no members' {
                $testGroupName = 'LocalTestGroup'
                $testDescription = 'Some Description'

                try
                {
                    New-Group -GroupName $testGroupName -Description $testDescription

                    $getTargetResourceResult = Get-TargetResource -GroupName $testGroupName
                    $getTargetResourceResultProperties = @( 'GroupName', 'Ensure', 'Description', 'Members' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargerResourceResultProperties

                    $getTargetResourceResult['GroupName']       | Should Be $testGroupName
                    $getTargetResourceResult['Ensure']          | Should Be 'Present'
                    $getTargetResourceResult['Description']     | Should Be $testDescription
                    $getTargetResourceResult['Members'].Count   | Should Be 0
                }
                finally
                {
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return hashtable with correct values when group is absent' {
                $testGroupName = 'AbsentGroup'

                $getTargetResourceResult = Get-TargetResource -GroupName $testGroupName

                $getResultAsHashTable = $getResult -as [hashtable]
                $getTargetResourceResultProperties = @( 'GroupName', 'Ensure' )

                Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargerResourceResultProperties

                $getTargetResourceResult['GroupName']   | Should Be $testGroupName
                $getTargetResourceResult['Ensure']      | Should Be 'Absent'
            }
        }

        Context 'Set-TargetResource' {
            It 'Should not remove an existing group when Ensure is Present' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    $setTargetResourceResult = Set-TargetResource $testGroupName -Ensure 'Present'

                    Test-GroupExists -GroupName $testGroupName | Should Be $true
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should not throw when only one member of the group specified in MembersToInclude' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    { Set-TargetResource $testGroupName -Ensure 'Present' -MembersToInclude @( $testUserName1 ) } | Should Not Throw
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should remove an existing group when Ensure is Absent' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    $setTargetResourceResult = Set-TargetResource -GroupName $testGroupName -Ensure 'Absent'

                    Test-GroupExists -GroupName $testGroupName | Should Be $false
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-Group -GroupName $testGroupName
                }
            }

            <#
                Verify that test group can be created with a domain user and credential
                and that creating a group without a credential does not throw any errors
                when we have domain trust set up.
            #>
            It 'Should correctly create a group with a domain user and credential' -Skip:$script:skipTestsWithCredentials {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription

                    $domainUserName = '?'
                    $domainUserPassword = '?'

                    $secureDomainUserPassword = ConvertTo-SecureString $domainUserPassword -AsPlainText -Force
                    $domainCredential = New-Object -TypeName 'PSCredential' -ArgumentList @( $domainUserName, $secureDomainUserPassword )

                    Set-TargetResource `
                        -GroupName $testGroupName `
                        -MembersToInclude @( $testUserName1, $testUserName2, $domainUserName ) `
                        -Credential $domainCredential `
                        -Description $testDescription

                    $testTargetResourceResult = Test-TargetResource `
                        -GroupName $testGroupName `
                        -MembersToInclude @( $testUserName1, $testUserName2, $domainUserName ) `
                        -Credential $domainCredential

                    $testTargetResourceResult | Should Be $true

                    $getTargetResourceResult = Get-TargetResource -GroupName $testGroupName -Credential $domainCredential
                    $getTargetResourceResultProperties = @( 'GroupName', 'Ensure', 'Description', 'Members' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargerResourceResultProperties

                    $getTargetResourceResult['GroupName']       | Should Be $testGroupName
                    $getTargetResourceResult['Ensure']          | Should Be 'Present'
                    $getTargetResourceResult['Description']     | Should Be $testDescription
                    $getTargetResourceResult['Members'].Count   | Should Be 3
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-Group -GroupName $testGroupName
                }
            }

            <#
                Verify that a group can be created with a domain user and credential
                and that a user account from a trusted domain can be resolved and added.

                This test creates a group and adds the following users as domain\username:
                    - a domain local administrator user from a primary domain
                    - a domain user from the domain with a two-way trust

                The credential for the domain local administrator user is used to resolve all user accounts.
            #>
            It 'Should create a new group with the trusted domain accounts and credential' -Skip:$script:skipTestsWithCredentials {
                $testGroupName = 'LocalTestGroup'
                $testDescription = 'Some Description'

                $primaryDomainAccount = '?'
                $twoWayTrustDomainAccount = '?'

                $membersToInclude = @( $primaryDomainAccount['DomainUserName'], $twoWayTrustDomainAccount['DomainUserName'] )
                $primaryDomainAccountCredential = $primaryDomainAccount['Credential']

                try
                {
                    Set-TargetResource -GroupName $testGroupName -MembersToInclude $membersToInclude -Credential $primaryDomainAccountCredential -Description $testDescription

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -MembersToInclude $membersToInclude -Credential $primaryDomainAccountCredential
                    $testTargetResourceResult | Should Be $true

                    $getTargetResourceResult = Get-TargetResource -GroupName $testGroupName -Credential $primaryDomainAccountCredential
                    $getTargetResourceResultProperties = @( 'GroupName', 'Ensure', 'Description', 'Members' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargerResourceResultProperties

                    $getTargetResourceResult['GroupName']       | Should Be $testGroupName
                    $getTargetResourceResult['Ensure']          | Should Be 'Present'
                    $getTargetResourceResult['Description']     | Should Be $testDescription
                    $getTargetResourceResult['Members'].Count   | Should Be $membersToInclude.Length
                }
                finally
                {
                    Remove-Group -GroupName $testGroupName
                }
            }

            <#
                Verify that a group can be created with domain user and credential and a user
                account can be added using the user's UPN name.

                This test creates a group and adds the following users using their UPN name:
                    - a domain local administrator user from a primary domain
                    - a domain user from the domain with a two-way trust

                The credential for the domain local administrator user is used to resolve all user accounts.
            #>
            It 'Should create a group with a domain user and credential and add a user by UPN name' -Skip:$script:skipTestsWithCredentials {
                $testGroupName = 'LocalTestGroup'
                $testDescription = 'Some Description'

                $primaryDomainAccount = '?'
                $twoWayTrustDomainAccount = '?'

                $membersToInclude = @( $primaryDomainAccount['UpnName'], $twoWayTrustDomainAccount['UpnName'] )
                $primaryDomainAccountCredential = $primaryDomainAccount['Credential']

                try
                {
                    Set-TargetResource -GroupName $testGroupName -MembersToInclude $membersToInclude -Credential $primaryDomainAccountCredential -Description $testDescription

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -MembersToInclude $membersToInclude -Credential $primaryDomainAccountCredential
                    $testTargetResourceResult | Should Be $true

                    $getTargetResourceResult = Get-TargetResource -GroupName $testGroupName -Credential $primaryDomainAccountCredential
                    $getTargetResourceResultProperties = @( 'GroupName', 'Ensure', 'Description', 'Members' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargerResourceResultProperties

                    $getTargetResourceResult['GroupName']       | Should Be $testGroupName
                    $getTargetResourceResult['Ensure']          | Should Be 'Present'
                    $getTargetResourceResult['Description']     | Should Be $testDescription
                    $getTargetResourceResult['Members'].Count   | Should Be $membersToInclude.Length
                }
                finally
                {
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should not create a group with a credential and an invalid domain user' -Skip:$script:skipTestsWithCredentials {
                $testGroupName = 'LocalTestGroup'
                $testDescription = 'Some Description'

                $primaryDomainAccount = '?'
                $invalidDomainAccountUserName = 'invaliduser@' + $primaryAccount['DomainName']

                $membersToInclude = @( $primaryDomainAccount['UpnName'], $invalidDomainAccountUserName )
                $primaryDomainAccountCredential = $primaryDomainAccount['Credential']

                { Set-TargetResource -GroupName $testGroupName -MembersToInclude $membersToInclude -Credential $primaryDomainAccountCredential -Description $testDescription } | Should Throw

                Test-GroupExists -GroupName $groupName | Should Be $false
            }

            <#
                Verify that a group can be created with domain user but no credential and a user account from a trusted domain can be resolved and added.

                This test creates a group and adds the following users as domain\username:
                    - a domain local administrator user from a primary domain
                    - a domain user from the domain with a two-way trust

                The domain trust is used to resolve all user accounts.
            #>
            It 'Should create a group with a domain user but no credential' -Skip:$script:skipTestsWithCredentials {
                $testGroupName = 'LocalTestGroup'
                $testDescription = 'Some Description'

                $primaryDomainAccount = '?'
                $twoWayTrustDomainAccount = '?'

                $membersToInclude = @( $primaryDomainAccount['DomainUserName'], $twoWayTrustDomainAccount['DomainUserName'] )

                try
                {
                    { Set-TargetResource -GroupName $testGroupName -MembersToInclude $membersToInclude -Description $testDescription } | Should Not Throw

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -MembersToInclude $membersToInclude
                    $testTargetResourceResult | Should Be $true

                    $getTargetResourceResult = Get-TargetResource -GroupName $testGroupName
                    $getTargetResourceResultProperties = @( 'GroupName', 'Ensure', 'Description', 'Members' )

                    Test-GetTargetResourceResult -GetTargetResourceResult $getTargetResourceResult -GetTargetResourceResultProperties $getTargerResourceResultProperties

                    $getTargetResourceResult['GroupName']       | Should Be $testGroupName
                    $getTargetResourceResult['Ensure']          | Should Be 'Present'
                    $getTargetResourceResult['Description']     | Should Be $testDescription
                    $getTargetResourceResult['Members'].Count   | Should Be $membersToInclude.Length
                }
                finally
                {
                    Remove-Group -GroupName $testGroupName
                }
            }

            # Verify that test group cannot be created with an invalid credential
            It 'Should not create a group with an invalid credential' -Skip:$script:skipTestsWithCredentials {
                $testGroupName = 'LocalTestGroup'
                $testDescription = 'Some Description'

                $testUserName1 = 'LocalTestUser1'
                $testUserPassword = 'StrongOne7.'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )

                # Domain user with invalid password
                $domainUserName = '?'
                $invalidDomainUserPassword = '?' + 'invalidstring'
                $secureInvalidDomainUserPassword = ConvertTo-SecureString -String $invalidDomainUserPassword -AsPlainText -Force

                $invalidDomainUserCredential = New-Object -TypeName 'System.Management.Automation.PSCredential' -ArgumentList @($domainUserName, $invalidDomainUserPassword)

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription

                    {
                        Set-TargetResource `
                            -GroupName $testGroupName `
                            -MembersToInclude @($testUserName1, $domainUserName) `
                            -Credential $invalidDomainUserCredential `
                            -Description $testDescription
                    } | Should Throw
                }
                finally
                {
                    Remove-Group -GroupName $testGroupName
                    Remove-User -UserName $testUserName1
                }
            }

            # Verify that test group cannot be created with invalid user info (cannot resolve user) when using domain trust
            It 'Should not create a group with an invalid domain user without a credential' -Skip:$script:skipTestsWithCredentials {
                $testGroupName = 'LocalTestGroup'
                $testDescription = 'Some Description'

                $testUserName1 = 'LocalTestUser1'
                $testUserPassword = 'StrongOne7.'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )

                # Domain user with invalid username
                $invalidDomainUserName = '?' + 'invalidstring'

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription

                    {
                        Set-TargetResource `
                            -GroupName $testGroupName `
                            -MembersToInclude $membersToInclude `
                            -Credential $primaryDomainAccountCredential `
                            -Description $testDescription `
                            -MembersToInclude @($testUserName1, $invalidDomainUserName)
                    } | Should Throw
                }
                finally
                {
                    Remove-Group -GroupName $testGroupName
                    Remove-User -UserName $testUserName1
                }
            }
        }

        Context 'Test-TargetResource' {
            It 'Should return true for existing group with description' {
                $testGroupName = 'LocalTestGroup'
                $testDescription = 'Some Description'

                try
                {
                    New-Group -GroupName $testGroupName -Description $testDescription

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -Description $testDescription
                    $testTargetResourceResult | Should Be $true
                }
                finally
                {
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return false for existing group with the wrong description' {
                $testGroupName = 'LocalTestGroup'
                $testDescription = 'Some Description'

                try
                {
                    New-Group -GroupName $testGroupName -Description $testDescription

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -Description 'Wrong description'
                    $testTargetResourceResult | Should Be $false
                }
                finally
                {
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return true for existing group with matching Members' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -Description $testDescription -Members @( $testUserName1, $testUserName2 )
                    $testTargetResourceResult | Should Be $true
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return false for existing group with mismatching Members' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'
                $testUserName3 = 'LocalTestUser3'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )
                $testCredential3 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName3, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription
                    New-User -Credential $testCredential3 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -Description $testDescription -Members @( $testUserName1, $testUserName2, $testUserName3 )
                    $testTargetResourceResult | Should Be $false
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-User -UserName $testUserName3
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return true for existing group with one matching MemberToInclude' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -Description $testDescription -MembersToInclude @( $testUserName1 )
                    $testTargetResourceResult | Should Be $true
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return true for existing group with matching MembersToInclude' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -Description $testDescription -MembersToInclude @( $testUserName1, $testUserName2 )
                    $testTargetResourceResult | Should Be $true
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return false for existing group with mismatching MembersToInclude' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'
                $testUserName3 = 'LocalTestUser3'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )
                $testCredential3 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName3, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription
                    New-User -Credential $testCredential3 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -Description $testDescription -MembersToInclude @( $testUserName1, $testUserName2, $testUserName3 )
                    $testTargetResourceResult | Should Be $false
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-User -UserName $testUserName3
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return true for existing group without MembersToExclude' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'
                $testUserName3 = 'LocalTestUser3'
                $testUserName4 = 'LocalTestUser4'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )
                $testCredential3 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName3, $secureTestPassword )
                $testCredential4 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName4, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription
                    New-User -Credential $testCredential3 -Description $testDescription
                    New-User -Credential $testCredential4 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -Description $testDescription -MembersToExclude @( $testUserName3, $testUserName4 )
                    $testTargetResourceResult | Should Be $true
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-User -UserName $testUserName3
                    Remove-User -UserName $testUserName4
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return false for existing group with MembersToExclude' {
                $testUserName1 = 'LocalTestUser1'
                $testUserName2 = 'LocalTestUser2'
                $testUserName3 = 'LocalTestUser3'
                $testUserName4 = 'LocalTestUser4'

                $testDescription = 'Some Description'
                $testUserPassword = 'StrongOne7.'

                $testGroupName = 'LocalTestGroup'

                $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force
                $testCredential1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName1, $secureTestPassword )
                $testCredential2 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName2, $secureTestPassword )
                $testCredential3 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName3, $secureTestPassword )
                $testCredential4 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUserName4, $secureTestPassword )

                try
                {
                    New-User -Credential $testCredential1 -Description $testDescription
                    New-User -Credential $testCredential2 -Description $testDescription
                    New-User -Credential $testCredential3 -Description $testDescription
                    New-User -Credential $testCredential4 -Description $testDescription

                    New-Group -GroupName $testGroupName -Description $testDescription -MemberUserNames @( $testUserName1, $testUserName2 )

                    $testTargetResourceResult = Test-TargetResource -GroupName $testGroupName -Description $testDescription -MembersToExclude @( $testUserName1, $testUserName3, $testUserName4 )
                    $testTargetResourceResult | Should Be $false
                }
                finally
                {
                    Remove-User -UserName $testUserName1
                    Remove-User -UserName $testUserName2
                    Remove-User -UserName $testUserName3
                    Remove-User -UserName $testUserName4
                    Remove-Group -GroupName $testGroupName
                }
            }

            It 'Should return false for a nonexistent group' {
                $absentGroupName = 'AbsentGroupName'

                $testTargetResourceResult = Test-TargetResource -GroupName $absentGroupName
                $testTargetResourceResult | Should Be $false
            }
        }
    }
}
