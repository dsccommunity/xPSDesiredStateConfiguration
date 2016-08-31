Configuration MSFT_xServiceResource_Add_Config {
    param
    (
        $ServiceName,
        $ServicePath,
        $ServiceDisplayName,
        $ServiceDescription,
        $ServiceDependsOn
    )
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    node localhost {
        xService Integration_Test {
            Name            = $ServiceName
            Ensure          = 'Present'
            Path            = $ServicePath
            StartupType     = 'Automatic'
            BuiltInAccount  = 'LocalSystem'
            DesktopInteract = $true
            State           = 'Running'
            DisplayName     = $ServiceDisplayName
            Description     = $ServiceDescription
            DependsOn       = $ServiceDependsOn
        }
    }
}
