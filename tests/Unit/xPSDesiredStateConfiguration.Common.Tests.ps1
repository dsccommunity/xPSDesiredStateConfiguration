#region HEADER
$script:projectPath = "$PSScriptRoot\..\.." | Convert-Path
$script:projectName = (Get-ChildItem -Path "$script:projectPath\*\*.psd1" | Where-Object -FilterScript {
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try
            { Test-ModuleManifest -Path $_.FullName -ErrorAction Stop
            }
            catch
            { $false
            })
    }).BaseName

$script:parentModule = Get-Module -Name $script:projectName -ListAvailable | Select-Object -First 1
$script:subModulesFolder = Join-Path -Path $script:parentModule.ModuleBase -ChildPath 'Modules'
Remove-Module -Name $script:parentModule -Force -ErrorAction 'SilentlyContinue'

$script:subModuleName = (Split-Path -Path $PSCommandPath -Leaf) -replace '\.Tests.ps1'
$script:subModuleFile = Join-Path -Path $script:subModulesFolder -ChildPath "$($script:subModuleName)/$($script:subModuleName).psm1"

Import-Module $script:subModuleFile -Force -ErrorAction Stop
#endregion HEADER

InModuleScope $script:subModuleName {
    Describe 'xPSDesiredStateConfiguration.Common\Set-DSCMachineRebootRequired' {
        Context 'When called' {
            It 'Should set the desired DSCMachineStatus value' {
                # Store the previous $global:DSCMachineStatus value
                $prevDSCMachineStatus = $global:DSCMachineStatus

                # Make sure DSCMachineStatus is set to a value that will have to be updated
                $global:DSCMachineStatus = 0

                # Set and test for the new value
                Set-DSCMachineRebootRequired
                $global:DSCMachineStatus | Should -Be 1

                # Revert to previous $global:DSCMachineStatus value
                $global:DSCMachineStatus = $prevDSCMachineStatus
            }
        }
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-ResourceSetCommonParameterString' {
        It 'Should return string containing the string parameter value for one string common parameter' {
            $parameters = @{
                Name                   = 'Name'
                CommonStringParameter1 = 'CommonParameter1'
            }

            $keyParameterName = 'Name'

            $commonParameterString = New-ResourceSetCommonParameterString -KeyParameterName $keyParameterName -Parameters $parameters
            $commonParameterString | Should -Be "CommonStringParameter1 = `"CommonParameter1`"`r`n"
        }

        It 'Should return string containing one variable reference for one credential common parameter' {
            $testUserName = 'testUserName'
            $secureTestPassword = ConvertTo-SecureString -String 'testPassword' -AsPlainText -Force

            $parameters = @{
                Name                       = 'Name'
                CommonCredentialParameter1 = New-Object -TypeName 'PSCredential' -ArgumentList @( $testUsername, $secureTestPassword )
            }

            $keyParameterName = 'Name'

            $commonParameterString = New-ResourceSetCommonParameterString -KeyParameterName $keyParameterName -Parameters $parameters
            $commonParameterString | Should -Be "CommonCredentialParameter1 = `$CommonCredentialParameter1`r`n"
        }

        It 'Should return string containing all parameters for two string common parameters and two int common parameters' {
            $parameters = @{
                Name                   = 'Name'
                CommonStringParameter1 = 'CommonParameter1'
                CommonStringParameter2 = 'CommonParameter2'
                CommonIntParameter1    = 1
                CommonIntParameter2    = 2
            }

            $keyParameterName = 'Name'

            $commonParameterString = New-ResourceSetCommonParameterString -KeyParameterName $keyParameterName -Parameters $parameters
            $commonParameterString.Contains("CommonStringParameter1 = `"CommonParameter1`"`r`n") | Should -Be $true
            $commonParameterString.Contains("CommonStringParameter2 = `"CommonParameter2`"`r`n") | Should -Be $true
            $commonParameterString.Contains("CommonIntParameter1 = `$CommonIntParameter1`r`n") | Should -Be $true
            $commonParameterString.Contains("CommonIntParameter2 = `$CommonIntParameter2`r`n") | Should -Be $true
        }
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-ResourceSetConfigurationString' {
        $newResourceSetConfigurationStringParams = @{
            ResourceName          = 'ResourceName'
            ModuleName            = 'ModuleName'
            KeyParameterName      = 'Name'
            KeyParameterValues    = @( 'KeyValue1' )
            CommonParameterString = "CommonCredentialParameter1 = `$CommonCredentialParameter1`r`n"
        }

        It 'Should return string with module import and one resource for one key value' {
            $resourceString = New-ResourceSetConfigurationString @newResourceSetConfigurationStringParams
            $resourceString | Should -Be ("Import-DscResource -Name ResourceName -ModuleName ModuleName`r`n" + `
                    "ResourceName Resource0`r`n{`r`nName = `"KeyValue1`"`r`n$($newResourceSetConfigurationStringParams['CommonParameterString'])}`r`n")
        }

        $newResourceSetConfigurationStringParams['KeyParameterValues'] = @( 'KeyValue1', 'KeyValue2' )

        It 'Should return string with module import and two resources for two key values' {
            $resourceString = New-ResourceSetConfigurationString @newResourceSetConfigurationStringParams
            $resourceString | Should -Be ("Import-DscResource -Name ResourceName -ModuleName ModuleName`r`n" + `
                    "ResourceName Resource0`r`n{`r`nName = `"KeyValue1`"`r`n$($newResourceSetConfigurationStringParams['CommonParameterString'])}`r`n" + `
                    "ResourceName Resource1`r`n{`r`nName = `"KeyValue2`"`r`n$($newResourceSetConfigurationStringParams['CommonParameterString'])}`r`n")
        }
    }

    Describe 'xPSDesiredStateConfiguration.Common\New-ResourceSetConfigurationScriptBlock' {
        $commonParameterString = 'CommonParameterString'
        $configurationString = 'ConfigurationString'

        Mock -CommandName 'New-ResourceSetCommonParameterString' -MockWith { return $commonParameterString }
        Mock -CommandName 'New-ResourceSetConfigurationString' -MockWith { return $configurationString }

        $newResourceSetConfigurationParams = @{
            ResourceName     = 'ResourceName'
            ModuleName       = 'ModuleName'
            KeyParameterName = 'KeyParameter'
            Parameters       = @{
                KeyParameter     = @( 'KeyParameterValue1', 'KeyParameterValue2' )
                CommonParameter1 = 'CommonParameterValue1'
                CommonParameter2 = 'CommonParameterValue2'
            }
        }

        $newResourceSetConfigurationScriptBlock = New-ResourceSetConfigurationScriptBlock @newResourceSetConfigurationParams

        It 'Should return a ScriptBlock' {
            $newResourceSetConfigurationScriptBlock -is [System.Management.Automation.ScriptBlock] | Should -Be $true
        }

        It 'Should return ScriptBlock of string returned from New-ResourceSetConfigurationString' {
            $newResourceSetConfigurationScriptBlock | Should -Match ([System.Management.Automation.ScriptBlock]::Create($configurationString))
        }

        It 'Should call New-ResourceSetConfigurationString with the correct ModuleName' {
            Assert-MockCalled -CommandName 'New-ResourceSetConfigurationString' -ParameterFilter {
                $ModuleName -eq $newResourceSetConfigurationParams['ModuleName']
            }
        }

        It 'Should call New-ResourceSetCommonParameterString with the correct KeyParameterName' {
            Assert-MockCalled -CommandName 'New-ResourceSetCommonParameterString' -ParameterFilter {
                $KeyParameterName -eq $newResourceSetConfigurationParams['KeyParameterName']
            }
        }

        It 'Should call New-ResourceSetCommonParameterString with the correct Parameters' {
            Assert-MockCalled -CommandName 'New-ResourceSetCommonParameterString' -ParameterFilter {
                $null -eq (Compare-Object -ReferenceObject $newResourceSetConfigurationParams['Parameters'] -DifferenceObject $Parameters)
            }
        }

        It 'Should call New-ResourceSetConfigurationString with the correct ResourceName' {
            Assert-MockCalled -CommandName 'New-ResourceSetConfigurationString' -ParameterFilter {
                $ResourceName -eq $newResourceSetConfigurationParams['ResourceName']
            }
        }

        It 'Should call New-ResourceSetConfigurationString with the correct KeyParameterValues' {
            Assert-MockCalled -CommandName 'New-ResourceSetConfigurationString' -ParameterFilter {
                $null -eq (Compare-Object -ReferenceObject $newResourceSetConfigurationParams['Parameters']['KeyParameter'] -DifferenceObject $KeyParameterValues)
            }
        }

        It 'Should call New-ResourceSetConfigurationString with the correct CommonParameterString' {
            Assert-MockCalled -CommandName 'New-ResourceSetConfigurationString' -ParameterFilter {
                $CommonParameterString -eq $commonParameterString
            }
        }
    }
}
