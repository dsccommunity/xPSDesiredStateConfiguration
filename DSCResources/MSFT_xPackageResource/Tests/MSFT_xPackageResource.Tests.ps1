#requires -Version 4.0

Remove-Module MSFT_xPackageResource -ErrorAction Ignore
$module = Import-Module $PSScriptRoot\..\MSFT_xPackageResource.psm1 -Force -PassThru -ErrorAction Stop

Describe 'Get-MsiTools' {
    It 'Uses Add-Type with a name that does not conflict with the original Package resource' {
        InModuleScope MSFT_xPackageResource {
            $hash = @{ Namespace = 'Mock not called' }
            Mock Add-Type { $hash['Namespace'] = $Namespace }
            $null = Get-MsiTools

            $hash['Namespace'] | Should Be 'Microsoft.Windows.DesiredStateConfiguration.xPackageResource'
        }
    }
}
