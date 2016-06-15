$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xPSDesiredStateConfiguration' `
    -DSCResourceName 'MSFT_xServiceSet' `
    -TestType Integration

Describe "xServiceSet Integration Tests" {
    BeforeAll {
        Import-Module "$PSScriptRoot\MSFT_xServiceSet.TestHelper.psm1"

        $script:testServiceName = "DscTestService"
        $script:testServiceCodePath = "$PSScriptRoot\DscTestService.cs"
        $script:testServiceDisplayName = "DSC test service display name"
        $script:testServiceDescription = "This is DSC test service used for testing ServiceSet composite resource"
        $script:testServiceDependsOn = "winrm"
        $script:testServiceExecutablePath = Join-Path -Path (Get-Location) -ChildPath "DscTestService.exe"

        Stop-Service $script:testServiceName -ErrorAction SilentlyContinue

        New-TestService `
            -ServiceName $script:testServiceName `
            -ServiceCodePath $script:testServiceCodePath `
            -ServiceDisplayName $script:testServiceDisplayName `
            -ServiceDescription $script:testServiceDescription `
            -ServiceDependsOn $script:testServiceDependsOn `
            -ServiceExecutablePath $script:testServiceExecutablePath
    }

    AfterAll {
        Remove-TestService -ServiceName $script:testServiceName -ServiceExecutablePath $script:testServiceExecutablePath
    }

    It "Changes the properties a set of services" -Pending { # This test requires several updates to xService. Will remove pending flag when those updates are complete.
        $configurationName = "ChangeServiceProperties"
        $configurationPath = Join-Path -Path (Get-Location) -ChildPath $configurationName

        try
        {
            Configuration $configurationName
            {
                Import-DscResource -ModuleName xPSDesiredStateConfiguration

                xServiceSet ServiceSet1
                {
                    Name = @($script:testServiceName)
                    Ensure = "Present"
                    State = "Running"
                    StartupType = "Automatic"
                    BuiltInAccount = "LocalService"
                }
            }

            & $configurationName -OutputPath $configurationPath

            Start-DscConfiguration -Path $configurationPath -Wait -Force -Verbose

            $testService = (Get-WmiObject -Class win32_service | Where-Object {$_.Name -eq $script:testServiceName})
            $testService | Should Not Be $null
            $testService.State | Should Be "Running"
            $testService.StartMode | Should Be "Auto"
            $testService.StartName.Contains("LocalService") | Should Be $true
        }
        finally
        {
            if (Test-Path -path $configurationPath)
            {
                Remove-Item -Path $configurationPath -Recurse -Force
            }
        }
    }

    It "Uses a set of services that depends on a file" {
        $configurationName = "UsingDependsOn"
        $configurationPath = Join-Path -Path (Get-Location) -ChildPath $configurationName
        $testDirectory = Join-Path -Path (Get-Location) -ChildPath "TestDirectory"

        try
        {
            Configuration $configurationName
            {
                Import-DscResource -ModuleName xPSDesiredStateConfiguration

                File TestDirectory
                {
                    DestinationPath = $testDirectory
                    Type = "Directory"
                    Ensure = "Present"
                }

                xServiceSet ServiceSet1
                {
                    Name = @($script:testServiceName)
                    Ensure = "Present"
                    State = "Stopped"
                    StartupType = "Manual"
                    BuiltInAccount = "LocalSystem"
                    DependsOn = "[File]TestDirectory"
                }
            }

            & $configurationName -OutputPath $configurationPath

            Start-DscConfiguration -Path $configurationPath -Wait -Force -Verbose

            $testService = (Get-WmiObject -Class win32_service | Where-Object {$_.Name -eq $script:testServiceName})
            $testService | Should Not Be $null
            $testService.State | Should Be "Stopped"
            $testService.StartMode | Should Be "Manual"
            $testService.StartName | Should Be "LocalSystem"
        }
        finally
        {
            if (Test-Path -Path $testDirectory)
            {
                Remove-Item -Path @($testDirectory) -Recurse -Force
            }

            if (Test-Path -Path $configurationPath)
            {
                Remove-Item -Path @($configurationPath) -Recurse -Force
            }
        }
    }
}
