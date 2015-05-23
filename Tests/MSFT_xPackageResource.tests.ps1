<# 
.summary
    Test suite for MSFT_xPackageResource.psm1
#>
[CmdletBinding()]
param()

Import-Module $PSScriptRoot\..\DSCResources\MSFT_xPackageResource\MSFT_xPackageResource.psm1

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest


function Suite.BeforeAll {
    # Remove any leftovers from previous test runs
    Suite.AfterAll 

}

function Suite.AfterAll {
    Remove-Module MSFT_xPackageResource
}

function Suite.BeforeEach {
}

try
{
    InModuleScope MSFT_xPackageResource {
    Describe 'Get-RegistryValueIgnoreError' {

        It 'Should get values from HKLM' {
                $installValue = Get-RegistryValueIgnoreError 'LocalMachine' "SOFTWARE\Microsoft\Windows\CurrentVersion" "ProgramFilesDir" Registry64
                $installValue | should be $env:programfiles
        }
        It 'Should get values from HKCU' {
                $installValue = Get-RegistryValueIgnoreError 'CurrentUser' "Environment" "Temp" Registry64
                $installValue.length -gt 3 | should be $true
                $envBeginning = $env:temp.substring(0,$installValue.length)
                $installValue | should be $envBeginning
        }

    }
    }
}
finally
{
    Suite.AfterAll
}

