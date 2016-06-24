[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
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

                    $getTargetResourceResult = Get-TargetResource -GroupName $testGroupName
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
            
                This test creates a group and adds the following users:
                    - a domain local administrator user from a primary domain as domain\username
                    - a domain user from the domain with a two-way trust as domain\username

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
                    
                    getTargetResourceResult = Get-TargetResource -GroupName $testGroupName
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

            It 'Should create a group with a domain user and credential and add a user by UPN name' -Skip:$script:skipTestsWithCredentials {
                #
                # Verify that a group can be created with domain user and credentials
                # and a user accounts can be added using the user's UPN name
                #
                # This test creates the group LocalGroupWithTrustedDomain and adds the following users
                # DomainLocalAdmin user from primary domain using the UPN name
                # DomainUser from the domain with a 2-way trust using the UPN name
                # The credentials for the DomainLocalAdmin account are used to resolve all user accounts.

                $groupName = "LocalGroupWithUpnNames"
                $groupDescription = "Group with user from a trusted domain"
                [bool] $passed = $false

                # Ensure the group doesn't exist
                Remove-Group -GroupName $groupName

                try
                {
                    # domain local admin of primary domain
                    $primaryAccount = DomainAccountGenerator -domain "Primary" -user "DomainLocalAdmin"
                    # a domain user from the 2-way trust domain
                    $twoAccount = DomainAccountGenerator -domain "TrustedTwo" -user "DomainUser"

                    $membersToInclude = @( $primaryAccount["UpnName"], $twoAccount["UpnName"])
                    $credential = $primaryAccount["Credential"]

                    # Create test group with credentials
                    MSFT_GroupResource\Set-TargetResource -GroupName $groupName -MembersToInclude $membersToInclude -Credential $credential -Description $groupDescription

                    # Test group created with credentials
                    $result = MSFT_GroupResource\Test-TargetResource -GroupName $groupName -MembersToInclude $membersToInclude -Credential $credential

                    if ($result -ne $true)
                    {
                        throw "Set target resource group with credentials: Test-TargetResource failed."
                    }

                    # Get group information.
                    $result = MSFT_GroupResource\Get-TargetResource -GroupName $groupName
                    $resultHashTable = $result -as [hashtable]

                    if ($resultHashTable -eq $null)
                    {
                        throw "Get target resource group with credentials failed."
                    }

                    $resultHashTable

                    AssertEquals $groupName $resultHashTable["GroupName"] "Get-TargetResource: Group name. $groupName expected."  
                    AssertEquals "Present" $resultHashTable["Ensure"] "Get-TargetResource: Ensure. 'Present' expected." 
                    AssertEquals  $groupDescription $resultHashTable["Description"] "Get-TargetResource: Description. $groupDescription expected"
                    $expectedLength = $membersToInclude.Length
                    AssertEquals $expectedLength $resultHashTable["Members"].Count "Get-TargetResource: Members.Count. $expectedLength expected"
                    $passed = $true
                }
                finally
                {
                    if ($passed -eq $true)
                    {
                        # Remove the group if the test passed; otherwise,
                        # leave the group to enable debugging
                        Remove-Group -GroupName $groupName
                    }
                }
            }

            It 'Should not create a group with a credential and an invalid domain user' -Skip:$script:skipTestsWithCredentials {
                Invoke-Remotely {
                    #
                    # Verify that a group can be created with domain user and credentials
                    # and a user accounts can be added using the user's UPN name
                    #
                    # This test creates the group LocalGroupWithTrustedDomain and adds the following users
                    # DomainLocalAdmin user from primary domain using the UPN name
                    # DomainUser from the domain with a 2-way trust using the UPN name
                    # The credentials for the DomainLocalAdmin account are used to resolve all user accounts.

                    $groupName = "TestGroup"
                    $groupDescription = "Group should not exist"
                    [bool] $passed = $false

                    # Ensure the group doesn't exist
                    Remove-Group -GroupName $groupName

                    # domain local admin of primary domain
                    $primaryAccount = DomainAccountGenerator -domain "Primary" -user "DomainLocalAdmin"
                    # a domain user from the 2-way trust domain
                    $twoAccount = "invaliduser@" + $primaryAccount["DomainName"]

                    $membersToInclude = @( $primaryAccount["UpnName"], $twoAccount)
                    $credential = $primaryAccount["Credential"]

                    try
                    {
                        MSFT_GroupResource\Set-TargetResource -GroupName $groupName -MembersToInclude $membersToInclude -Credential $credential -Description $groupDescription
                        #   -Credential $cred
                    }
                    catch
                    {
                        $errorRecord = $_
                    }

                    if (($errorRecord -eq $null) -or ($errorRecord.FullyQualifiedErrorId -notmatch "PrincipalNotFound_ProvidedCredential"))
                    {
                        throw "Set target with invalid names: Did not throw 'PrincipalNotFound_ProvidedCredential' error."
                    }

                    $groupExists = Test-Group $groupName

                    AssertEquals $false $groupExists "Set-TargetResource: Group.Exists. $groupName should not have been created." 
                }
            }

            It 'Should create a group with a domain user but no credential' -Skip:$script:skipTestsWithCredentials {
                Invoke-Remotely {

                    #
                    # Verify that a group can be created with domain user but no credentials
                    # and a user account from a trusted domain can be resolved and added.
                    #
                    # This test creates the group LocalGroupWithTrustedDomainButNoCredentials and adds the following users
                    # DomainLocalAdmin user from primary domain as domain\username
                    # DomainUser from the domain with a 2-way trust as domain\username
                    # Since no credentials are provided, the domain trust is used to resolve all user accounts.

                    $groupName = "LocalGroupWithTrustedDomainButNoCredentials"
                    $groupDescription = "Group with user from a trusted domain without credentials"
                    [bool] $passed = $false

                    try
                    {
                        # domain local admin of primary domain
                        $primaryAccount = DomainAccountGenerator -domain "Primary" -user "DomainLocalAdmin"
                        # a domain user from the 2-way trust domain
                        $twoAccount = DomainAccountGenerator -domain "TrustedTwo" -user "DomainUser"

                        $membersToInclude = @($primaryAccount["DomainUserName"], $twoAccount["DomainUserName"])
                        $credential = $null

                        # Create test group without credentials
                        AssertNoError { MSFT_GroupResource\Set-TargetResource -GroupName $groupName -MembersToInclude $membersToInclude -Description $groupDescription } `
                            "Set target failed to add local users to a local group without credentials"

                        # Test group created without credentials
                        $result = MSFT_GroupResource\Test-TargetResource -GroupName $groupName -MembersToInclude $membersToInclude

                        if ($result -ne $true)
                        {
                            throw "Set target resource group with credentials: Test-TargetResource failed."
                        }

                        # Get group information.
                        $result = MSFT_GroupResource\Get-TargetResource -GroupName $groupName
                        $resultHashTable = $result -as [hashtable]

                        if ($resultHashTable -eq $null)
                        {
                            throw "Get target resource group without credentials failed."
                        }

                        $resultHashTable

                        AssertEquals $groupName $resultHashTable["GroupName"] "Get-TargetResource: Group name. $groupName expected."  
                        AssertEquals "Present" $resultHashTable["Ensure"] "Get-TargetResource: Ensure. 'Present' expected." 
                        $expectedLength = $membersToInclude.Length
                        AssertEquals $expectedLength $resultHashTable["Members"].Count "Get-TargetResource: Members.Count. $expectedLength expected"
                        $passed = $true
                    }
                    finally
                    {
                        if ($passed -eq $true)
                        {
                            # Remove the group if the test passed; otherwise,
                            # leave the group to enable debugging
                            Remove-Group -GroupName $groupName
                        }
                    }
                }
            }

            It 'Should not create a group with an invalid credential' -Skip:$script:skipTestsWithCredentials {

                Invoke-Remotely {

                    #
                    # Verify that test group cannot be created with invalid credentials
                    #

                    $TestUserName1 = "LocalTestUser51"
                    $TestDescription = "Test User Description"
                    $TestGroupName = "LocalTestGroupInvalidCredential"

                    try
                    {
                        # Local users
                        New-User -UserName $TestUserName1 -Password "StrongOne7." -Description $TestDescription

                        # Domain user with invalid password
                        $username = (DomainLocalAdminUserGenerator)
                        $invalidpassword = ((DomainLocalAdminPasswordGenerator)+"randomstring") | ConvertTo-SecureString -AsPlainText -Force

                        $invalidcred = New-Object System.Management.Automation.PSCredential($username, $invalidpassword)

                        # Create test group with invalid credentials
                        AssertFullyQualifiedErrorIdEquals { MSFT_GroupResource\Set-TargetResource -GroupName $TestGroupName -MembersToInclude @($TestUserName1, $username) `
                            -Credential $invalidcred -Description $TestDescription } `
                            -expectedFullyQualifiedErrorId 'PrincipalNotFound'
                    }
                    finally
                    {
                        Remove-Group -GroupName $TestGroupName
                        Remove-User -UserName $TestUserName1
                    }
                }
            }
    
            It 'Should not create a group with an invalid domain user without a credential' -Skip:$script:skipTestsWithCredentials {

                Invoke-Remotely {

                    #
                    # Verify that test group cannot be created with invalid user info (cannot resolve user) when
                    # no credentials is passed and we are using domain trust
                    #

                    $TestUserName1 = "LocalTestUser51"
                    $TestDescription = "Test User/Group Description"
                    $TestGroupName = "LocalTestGroupInvalidDomainUser"

                    try
                    {
                        # Local users
                        New-User -UserName $TestUserName1 -Password "StrongOne7." -Description $TestDescription

                        # Domain user with invalid username
                        $username = (DomainLocalAdminUserGenerator)+"randomstring"

                        # Create test group with invalid credentials
                        AssertFullyQualifiedErrorIdEquals { MSFT_GroupResource\Set-TargetResource -GroupName $TestGroupName -MembersToInclude @($TestUserName1, $username) `
                            -Description $TestDescription } `
                            -expectedFullyQualifiedErrorId 'PrincipalNotFound_ProvidedCredential'
                    }
                    finally
                    {
                        Remove-Group -GroupName $TestGroupName
                        Remove-User -UserName $TestUserName1
                    }
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
