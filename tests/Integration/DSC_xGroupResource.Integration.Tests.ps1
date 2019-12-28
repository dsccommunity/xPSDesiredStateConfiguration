[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xGroupResource'

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
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\DSC_xGroupResource.TestHelper.psm1')

# Begin Testing
try
{
    Describe 'xGroup Integration Tests' {
        BeforeAll {
            $script:confgurationNoMembersFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xGroupResource_NoMembers.config.ps1'
            $script:confgurationWithMembersFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xGroupResource_Members.config.ps1'
            $script:confgurationWithMembersToIncludeExcludeFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xGroupResource_MembersToIncludeExclude.config.ps1'

            # Fake users for testing
            $script:testUsername1 = 'TestUser1'
            $script:testUsername2 = 'TestUser2'

            $script:testUsernames = @( $script:testUsername1, $script:testUsername2 )

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

        It 'Should create an empty group' {
            $configurationName = 'CreateEmptyGroup'
            $testGroupName = 'TestEmptyGroup1'

            $resourceParameters = @{
                Ensure = 'Present'
                GroupName = $testGroupName
            }

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeFalse

            try
            {
                {
                    . $script:confgurationWithMembersFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @resourceParameters
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName -Members @() | Should -BeTrue
            }
            finally
            {
                if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName)
                {
                    DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName
                }
            }
        }

        It 'Should not change the state of the present built-in Users group when no Members specified' {
            $configurationName = 'BuiltInGroup'
            $testGroupName = 'Users'

            $resourceParameters = @{
                Ensure = 'Present'
                GroupName = $testGroupName
            }

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeTrue

            {
                . $script:confgurationNoMembersFilePath -ConfigurationName $configurationName
                & $configurationName -OutputPath $TestDrive @resourceParameters
                Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
            } | Should -Not -Throw

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeTrue
        }

        It 'Should add a member to the built-in Users group with MembersToInclude' {
            $configurationName = 'BuiltInGroup'
            $testGroupName = 'Users'

            $resourceParameters = @{
                Ensure = 'Present'
                GroupName = $testGroupName
                MembersToInclude = $script:testUsername1
            }

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeTrue

            {
                . $script:confgurationWithMembersToIncludeExcludeFilePath -ConfigurationName $configurationName
                & $configurationName -OutputPath $TestDrive @resourceParameters
                Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
            } | Should -Not -Throw

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName -MembersToInclude $script:testUsername1 | Should -BeTrue
        }

        It 'Should create a group with two test users using Members' {
            $configurationName = 'CreateGroupWithTwoMembers'
            $testGroupName = 'TestGroupWithMembers2'

            $groupMembers = $script:testUsernames

            $resourceParameters = @{
                Ensure = 'Present'
                GroupName = $testGroupName
                Members = $groupMembers
            }

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeFalse

            try
            {
                {
                    . $script:confgurationWithMembersFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @resourceParameters
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName -Members $groupMembers | Should -BeTrue
            }
            finally
            {
                if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName)
                {
                    DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName
                }
            }
        }

        It 'Should add a member to a group with MembersToInclude' {
            $configurationName = 'CreateGroupWithTwoMembers'
            $testGroupName = 'TestGroupWithMembersToInclude3'

            $groupMembers = @( $script:testUsername1 )

            $resourceParameters = @{
                Ensure = 'Present'
                GroupName = $testGroupName
                MembersToInclude = $groupMembers
            }

            try
            {
                DSC_xGroupResource.TestHelper\New-Group -GroupName $testGroupName
            }
            catch
            {
                Write-Verbose "Group $testGroupName already exists OR there was an error creating it."
            }

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeTrue

            try
            {
                {
                    . $script:confgurationWithMembersToIncludeExcludeFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @resourceParameters
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName -MembersToInclude $groupMembers | Should -BeTrue
            }
            finally
            {
                if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName)
                {
                    DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName
                }
            }
        }

        It 'Should remove a member from a group with MembersToExclude' {
            $configurationName = 'CreateGroupWithTwoMembers'
            $testGroupName = 'TestGroupWithMembersToInclude3'

            $groupMembersToExclude = @( $script:testUsername1 )

            $resourceParameters = @{
                Ensure = 'Present'
                GroupName = $testGroupName
                MembersToExclude = $groupMembersToExclude
            }

            try
            {
                DSC_xGroupResource.TestHelper\New-Group -GroupName $testGroupName -Members $groupMembersToExclude
            }
            catch
            {
                Write-Verbose "Group $testGroupName already exists OR there was an error creating it."
            }

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeTrue

            try
            {
                {
                    . $script:confgurationWithMembersToIncludeExcludeFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @resourceParameters
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName -MembersToExclude $groupMembersToExclude | Should -BeTrue
            }
            finally
            {
                if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName)
                {
                    DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName
                }
            }
        }

        It 'Should remove a group' {
            $configurationName = 'RemoveGroup'
            $testGroupName = 'TestRemoveGroup1'

            $resourceParameters = @{
                Ensure = 'Absent'
                GroupName = $testGroupName
            }

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeFalse

            DSC_xGroupResource.TestHelper\New-Group -GroupName $testGroupName

            DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeTrue

            try
            {
                {
                    . $script:confgurationWithMembersFilePath -ConfigurationName $configurationName
                    & $configurationName -OutputPath $TestDrive @resourceParameters
                    Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force
                } | Should -Not -Throw

                DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName | Should -BeFalse
            }
            finally
            {
                if (DSC_xGroupResource.TestHelper\Test-GroupExists -GroupName $testGroupName)
                {
                    DSC_xGroupResource.TestHelper\Remove-Group -GroupName $testGroupName
                }
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
