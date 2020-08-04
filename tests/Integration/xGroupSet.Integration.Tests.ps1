[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'xGroupSet'

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
    -TestType 'Integration'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\DSC_xGroupResource.TestHelper.psm1')

# Begin Testing
try
{
    Describe 'xGroupSet Integration Tests' {
        BeforeAll {
            $script:confgurationFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'xGroupSet.config.ps1'

            # Fake users for testing
            $script:testUsername1 = 'TestUser1'
            $script:testUsername2 = 'TestUser2'
            $script:testUsername3 = 'TestUser3'

            $script:testUsernames = @( $script:testUsername1, $script:testUsername2, $script:testUsername3 )

            $script:testPassword = 'T3stPassw0rd#'
            $script:secureTestPassword = ConvertTo-SecureString -String $script:testPassword -AsPlainText -Force

            foreach ($username in $script:testUsernames)
            {
                $testUserCredential = New-Object -TypeName 'System.Management.Automation.PSCredential' -ArgumentList @( $username, $script:secureTestPassword )
                $null = DSC_xGroupResource.TestHelper\New-User -Credential $testUserCredential
            }
        }

        AfterAll {
            foreach ($username in $script:testUsernames)
            {
                DSC_xGroupResource.TestHelper\Remove-User -UserName $username
            }
        }

        It 'Should create a set of two empty groups' {
            $configurationName = 'CreateEmptyGroups'

            $testGroupName1 = 'TestEmptyGroup1'
            $testGroupName2 = 'TestEmptyGroup2'

            $groupSetParameters = @{
                GroupName = @( $testGroupName1, $testGroupName2 )
                Ensure = 'Present'
            }

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName1 | Should -BeFalse
            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName2 | Should -BeFalse

            try
            {
                {
                    . $script:confgurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @groupSetParameters
                    Reset-DscLcm
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName1 -Members @() | Should -BeTrue
                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName2 -Members @() | Should -BeTrue
            }
            finally
            {
                if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName1)
                {
                    DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName1
                }

                if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName2)
                {
                    DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName2
                }
            }
        }

        It 'Should create a set of one group with one member' {
            $configurationName = 'CreateOneGroup'

            $testGroupName1 = 'TestGroup1'
            $groupMembers = @( $script:testUsername1 )

            $groupSetParameters = @{
                GroupName = @( $testGroupName1 )
                Ensure = 'Present'
                MembersToInclude = $groupMembers
            }

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName1 | Should -BeFalse

            try
            {
                {
                    . $script:confgurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @groupSetParameters
                    Reset-DscLcm
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName1 -MembersToInclude $groupMembers | Should -BeTrue
            }
            finally
            {
                if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName1)
                {
                    DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName1
                }
            }
        }

        It 'Should create one group with one member and add the same member to the Administrators group' {
            $configurationName = 'CreateOneGroupAndModifyAdministrators'

            $testGroupName = 'TestGroupWithMember'
            $administratorsGroupName = 'Administrators'

            $groupMembers = @( $script:testUsername1 )

            $groupSetParameters = @{
                GroupName = @( $testGroupName, $administratorsGroupName )
                Ensure = 'Present'
                MembersToInclude = $groupMembers
            }

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeFalse
            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $administratorsGroupName | Should -BeTrue

            try
            {
                {
                    . $script:confgurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @groupSetParameters
                    Reset-DscLcm
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName -MembersToInclude $groupMembers | Should -BeTrue
                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $administratorsGroupName -MembersToInclude $groupMembers | Should -BeTrue
            }
            finally
            {
                if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName)
                {
                    DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName
                }
            }
        }

        It 'Should remove two members from a set of three groups' {
            $configurationName = 'RemoveTwoMembersFromThreeGroups'

            $testGroupNames = @('TestGroupWithMembersToExclude1', 'TestGroupWithMembersToExclude2', 'TestGroupWithMembersToExclude3')

            $groupMembersToExclude = @( $script:testUsername2, $script:testUsername3 )

            $groupSetParameters = @{
                GroupName = $testGroupNames
                Ensure = 'Present'
                MembersToExclude = $groupMembersToExclude
            }

            foreach ($testGroupName in $testGroupNames)
            {
                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeFalse

                DSC_xGroupResource.TestHelper\New-Group -GroupName $testGroupName -Members $script:testUsernames

                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeTrue
            }

            try
            {
                {
                    . $script:confgurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @groupSetParameters
                    Reset-DscLcm
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                foreach ($testGroupName in $testGroupNames)
                {
                    DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName -MembersToExclude $groupMembersToExclude | Should -BeTrue
                }
            }
            finally
            {
                foreach ($testGroupName in $testGroupNames)
                {
                    if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName)
                    {
                        DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName
                    }
                }
            }
        }

        It 'Should remove a set of groups' {
                $configurationName = 'RemoveThreeGroups'

            $testGroupNames = @('TestGroupRemove1', 'TestGroupRemove2', 'TestGroupRemove3')

            $groupSetParameters = @{
                GroupName = $testGroupNames
                Ensure = 'Absent'
            }


            foreach ($testGroupName in $testGroupNames)
            {
                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeFalse

                DSC_xGroupResource.TestHelper\New-Group -GroupName $testGroupName

                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeTrue
            }

            try
            {
                {
                    . $script:confgurationFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @groupSetParameters
                    Reset-DscLcm
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                foreach ($testGroupName in $testGroupNames)
                {
                    DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeFalse
                }
            }
            finally
            {
                foreach ($testGroupName in $testGroupNames)
                {
                    if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName)
                    {
                        DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName
                    }
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
