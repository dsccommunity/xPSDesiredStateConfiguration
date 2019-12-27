$script:dscModuleName = 'xPSDesiredStateConfiguration'
$script:dscResourceName = 'DSC_xMsiPackage'

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
    -TestType 'Unit'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\DSC_xPackageResource.TestHelper.psm1')

# Begin Testing
try
{
    InModuleScope $script:dscResourceName {
        Describe 'xPackageResource Integration Tests' {
            BeforeAll {
                $script:testDirectoryPath = Join-Path -Path $PSScriptRoot -ChildPath 'DSC_xPackageResourceTests'

                if (Test-Path -Path $script:testDirectoryPath)
                {
                    Remove-Item -Path $script:testDirectoryPath -Recurse -Force | Out-Null
                }

                New-Item -Path $script:testDirectoryPath -ItemType 'Directory' | Out-Null

                $script:msiName = 'DSCSetupProject.msi'
                $script:msiLocation = Join-Path -Path $script:testDirectoryPath -ChildPath $script:msiName

                $script:packageName = 'DSCUnitTestPackage'
                $script:packageId = '{deadbeef-80c6-41e6-a1b9-8bdb8a05027f}'

                New-TestMsi -DestinationPath $script:msiLocation | Out-Null

                Clear-PackageCache | Out-Null
            }

            BeforeEach {
                Clear-PackageCache | Out-Null

                if (Test-PackageInstalledByName -Name $script:packageName)
                {
                    Start-Process -FilePath 'msiexec.exe' -ArgumentList @("/x$script:packageId", '/passive') -Wait | Out-Null
                    Start-Sleep -Seconds 1 | Out-Null
                }

                if (Test-PackageInstalledByName -Name $script:packageName)
                {
                    throw 'Package could not be removed.'
                }
            }

            AfterAll {
                if (Test-Path -Path $script:testDirectoryPath)
                {
                    Remove-Item -Path $script:testDirectoryPath -Recurse -Force | Out-Null
                }

                Clear-PackageCache | Out-Null

                if (Test-PackageInstalledByName -Name $script:packageName)
                {
                    Start-Process -FilePath 'msiexec.exe' -ArgumentList @("/x$script:packageId", '/passive') -Wait | Out-Null
                    Start-Sleep -Seconds 1 | Out-Null
                }

                if (Test-PackageInstalledByName -Name $script:packageName)
                {
                    throw 'Test output will not be valid - package could not be removed.'
                }
            }

            It 'Install a .msi package' {
                $configurationName = 'EnsurePackageIsPresent'
                $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

                try
                {
                    $configurationScriptText = @"
Configuration $configurationName
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xPackage Package1
    {
        Path = '$script:msiLocation'
        Ensure = "Present"
        Name = '$script:packageName'
        ProductId = '$script:packageId'
    }
}
"@
                    .([System.Management.Automation.ScriptBlock]::Create($configurationScriptText))

                    & $configurationName -OutputPath $configurationPath

                    Start-DscConfiguration -Path $configurationPath -Wait -Force

                    Test-PackageInstalledByName -Name $script:packageName | Should -BeTrue
                }
                finally
                {
                    if (Test-Path -Path $configurationPath)
                    {
                        Remove-Item -Path $configurationPath -Recurse -Force
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
