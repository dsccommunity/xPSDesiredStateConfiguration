$ErrorActionPreference = 'Stop'

Get-Module MSFT_xRegistryResource | Remove-Module -Force
Import-Module $PSScriptRoot\..\DSCResources\MSFT_xRegistryResource\MSFT_xRegistryResource.psm1 -Prefix UnitTest

Describe 'MSFT_xRegistryResource' {
    BeforeAll {
        $rootPath = 'Software\__MSFT_xRegistryResource__'
        $rootPathWithDrive = "HKCU:\$rootPath"
        if (Test-Path -LiteralPath $rootPathWithDrive)
        {
            Remove-Item -LiteralPath $rootPathWithDrive -Recurse -Force
        }

        New-Item -Path $rootPathWithDrive
    }

    AfterAll {
        if (Test-Path -LiteralPath $rootPathWithDrive)
        {
            Remove-Item -LiteralPath $rootPathWithDrive -Recurse -Force
        }
    }

    It 'Supports keys containing forward slashes' {
        $keyName = 'Test/Key'
        $valueName = 'Testing'
        $valueData = 'TestValue'

        $scriptBlock = {
            Set-UnitTestTargetResource -Key $rootPathWithDrive\$keyName `
                                       -ValueName $valueName `
                                       -ValueData $valueData `
                                       -ValueType String `
                                       -Force $true `
                                       -ErrorAction Stop
        }

        $scriptBlock | Should Not Throw

        $regKey = (Get-Item HKCU:\).OpenSubKey("$rootPath\$keyName")
        
        $regKey | Should Not Be Null
        $regKey.GetValue($valueName) | Should Be $valueData
    }
}

