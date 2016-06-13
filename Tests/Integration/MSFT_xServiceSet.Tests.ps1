$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xServiceSet' `
    -TestType Integration 

Describe "xServiceSet Integration Tests" {
    BeforeAll {
        Import-Module "$PSScriptRoot\MSFT_xServiceSet.TestHelper.psm1"

        $script:testServiceName = "DSCtestService"
        $script:testServiceCodePath = Join-Path -Path (Get-Location) -ChildPath "DSCTestService.cs"
        $script:testServiceDisplayName = "DSC test service display name"
        $script:testServiceDescription = "This is DSC test service used for testing ServiceSet composite resource"
        $script:testServiceDependsOn = "winrm"
        $script:testServiceExecutablePath = "$currentDirectory\DSCTestService.exe"

        New-TestService `
            -ServiceName $script:testServiceName `
            -ServiceCodePath $script:testServiceCodePath `
            -ServiceDisplayName $script:testServiceDisplayName `
            -ServiceDescription $script:testServiceDescription `
            -ServiceDependsOn $script:testServiceDependsOn `
            -ServiceExecutablePath $script:testServiceExecutablePath
    }

    AfterAll {
        Remove-Service -ServiceName $script:testServiceName -ServiceExecutablePath $script:testServiceExecutablePath
    }

    It "Changes the properties a set of services" -Pending {
        Invoke-Remotely {
            $configurationName = "ChangeServiceProperties"
            $configurationPath = "$currentDirectory\$configName"

            try
            {
                Configuration $configName
                {
                    Import-DscResource -Name ServiceSet -ModuleName PSDesiredStateConfiguration
                    ServiceSet svc1
                    {
                        Name = @($script:testServiceName)
                        Ensure = "Present"
                        State = "Running"
                        StartupType = "Automatic"
                        BuiltInAccount = "LocalService"
                    }
                }

                & $configName -OutputPath $configDir

                Start-DscConfiguration -Path $configDir -Wait -Force -Verbose

                $testService = (Get-WmiObject -Class win32_service | where {$_.Name -eq $global:testServiceName})
                AssertNotNull $testService "Test Service should not be null"
                AssertEquals $testService.State "Running"
                AssertEquals $testService.StartMode "Auto"
                ($testService.StartName).Contains("LocalService") | Should Be $true
            }
            finally
            {
                if(Test-Path -path $configDir)
                {
                    Remove-Item -Path $configDir -Recurse -Force
                }
            }
        }
    } 
    
    #Summary: Uses Depends on with composite resource
    It "Uses DependsOn with a set of services that depends on a file" -Skip:(-not $shouldRun) {
        Invoke-Remotely {
            $configName = "UsingDependsOn"
            $configDir = "$currentDirectory\$configName"
            $testDir = "$currentDirectory\TestDirectory"

            try
            {
                Configuration $configName
                {
                    Import-DscResource -Name ServiceSet -ModuleName PSDesiredStateConfiguration
                    
                    File TestDirectory
                    {
                        DestinationPath = $testDir
                        Type = "Directory"
                        Ensure = "Present"
                    }

                    ServiceSet svc1
                    {
                        Name = @($global:testServiceName)
                        Ensure = "Present"
                        State = "Stopped"
                        StartupType = "Manual"
                        BuiltInAccount = "LocalSystem"
                        DependsOn = "[File]TestDirectory"
                    }
                }

                & $configName -OutputPath $configDir

                Start-DscConfiguration -Path $configDir -Wait -Force -Verbose

                $testService = (Get-WmiObject -Class win32_service | where {$_.Name -eq $global:testServiceName})
                AssertNotNull $testService "Test Service should not be null"
                AssertEquals $testService.State "Stopped"
                AssertEquals $testService.StartMode "Manual"
                AssertEquals $testService.StartName "LocalSystem"
            }
            finally
            {
                if(Test-Path -path $configDir,$testDir)
                {
                    Remove-Item -Path @($configDir,$testDir) -Recurse -Force 
                }
            }
        }
    }
}