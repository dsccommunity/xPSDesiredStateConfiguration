# Warning: These tests will create temporary administrators on the machine on which they are run

Describe "xGroupSet Tests" {

    BeforeAll {
        Import-Module "$PSScriptRoot\MSFT_xGroupResource.TestHelper.psm1"
        
        <#
        $script:testAdministratorUserName = "xMUser6789"
        $script:testAdministratorPassword = "StrongOne7."

        
        try
        {
            net user /add $script:testAdministratorUserName $script:TestPasswd
            net localgroup administrators $script:testAdministratorUserName /add
        }
        catch
        {
            throw "Failed to create local administrator ($script:testAdministratorUserName) for testing. Error message: $_"
        }
        #>
    }

    AfterAll {
        <#
        try
        {
            net user $script:testAdministratorUserName /DELETE
        }
        catch
        {
            throw "Failed to delete local administrator ($script:testAdministratorUserName) created for testing. Error message: $_"
        }
        #>
    }

    It "Create an xGroupSet" -Pending {
        $configurationName = "CreateTestGroup"
        $configurationPath = Join-Path -Path (Get-Location) -ChildPath $configurationName

        $testUserName1 = "LocalTestUser1"
        $testUserName2 = "LocalTestUser2"
        $testUserPassword = "StrongOne7."
        $testUserDescription = "Test users for creating an xGroupSet"

        $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force

        $testCredential1 = New-Object PSCredential ($testUserName1, $secureTestPassword)
        $testCredential2 = New-Object PSCredential ($testUserName2, $secureTestPassword)

        New-User -Credential $testCredential1 -Description $testUserDescription
        New-User -Credential $testCredential2 -Description $testUserDescription

        $membersToInclude = @($testUserName1, $testUserName2)
        $groupNames = @("TestGroupName123", "TestGroupName456")

        try
        {
            Configuration $configurationName
            {
                Import-DscResource -Name xGroupSet -ModuleName xPSDesiredStateConfiguration
                
                xGroupSet GroupSet1
                {
                    GroupName = $groupNames
                    Ensure = "Present"
                    MembersToInclude = $membersToInclude
                }
            }

            & $configurationName -OutputPath $configurationPath

            Start-DscConfiguration -Path  $configurationPath -Wait -Force -Verbose
            
            if (Test-IsNanoServer)
            {
                foreach ($groupName in $groupNames)
                {
                    $localGroup = Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue
                    $localGroup | Should Not Be $null
                }
            }
            else
            {
                $groupEntries = [ADSI] "WinNT://$env:ComputerName"

                foreach ($groupName in $groupNames)
                {
                    $groupEntry = $groupEntries.Children | Where-Object Path -like "WinNT://*$env:ComputerName/$groupName"
                    $groupEntry | Should Not Be $null
                }
            }
        }
        finally
        {
            Remove-User $testUserName1

            Remove-User $testUserName2

            if (Test-Path $configurationPath)
            {
                Remove-Item -Path $configurationPath -Recurse -Force
            }
        }
    } 

    It "Remove an xGroupSet" -Pending {
        $configurationName = "CreateTestGroup"
        $configurationPath = Join-Path -Path (Get-Location) -ChildPath $configurationName

        $testUserName1 = "LocalTestUser1"
        $testUserName2 = "LocalTestUser2"
        $testUserPassword = "StrongOne7."
        $testUserDescription = "Test users for removing an xGroupSet"

        $secureTestPassword = ConvertTo-SecureString $testUserPassword -AsPlainText -Force

        $testCredential1 = New-Object PSCredential ($testUserName1, $secureTestPassword)
        $testCredential2 = New-Object PSCredential ($testUserName2, $secureTestPassword)

        New-User -Credential $testCredential1 -Description $testUserDescription
        New-User -Credential $testCredential2 -Description $testUserDescription

        $membersToExclude = @($testUserName1, $testUserName2)
        $groupNames = @("TestGroupName123", "TestGroupName456")

        # Create test groups
        foreach($groupName in $groupNames)
        {
            New-LocalUserGroup -GroupName $groupName -Description $testUserDescription
        }

        try
        {
            Configuration $configurationName
            {
                Import-DscResource -Name xGroupSet -ModuleName xPSDesiredStateConfiguration
                
                xGroupSet GroupSet1
                {
                    GroupName = $groupNames
                    Ensure = "Absent"
                    MembersToExclude = $membersToExclude
                }
            }

            & $configurationName -OutputPath $configurationPath
            Start-DscConfiguration -Path $configurationPath -Wait -Force -Verbose

            if (Test-IsNanoServer)
            {
                foreach ($groupName in $groupNames)
                {
                    $localGroup = Get-LocalGroup -Name $groupName -ErrorAction Ignore
                    $localGroup | Should Be $null
                }
            }
            else
            {
                $groupEntries = [ADSI] "WinNT://$env:ComputerName"
                foreach($groupName in $groupNames)
                {
                    $groupEntry = $groupEntries.Children | Where-Object Path -like "WinNT://*$env:ComputerName/$groupName"
                    $groupEntry | Should Be $null
                }
            }
                
        }
        finally
        {
            Remove-User $testUserName1

            Remove-User $testUserName2

            if (Test-Path $configurationPath)
            {
                Remove-Item -Path $configurationPath -Recurse -Force
            }
        }
    } 
}