Configuration MSFT_xServiceResource_Add_Config {
    param
    (
        $ServiceName,
        $ServicePath,
        $ServiceDisplayName,
        $ServiceDescription,
        $ServiceDependencies
    )
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    node localhost {
        xService AddService {
            Name            = $ServiceName
            Ensure          = 'Present'
            Path            = $ServicePath
            StartupType     = 'Automatic'
            BuiltInAccount  = 'LocalSystem'
            DesktopInteract = $true
            State           = 'Running'
            DisplayName     = $ServiceDisplayName
            Description     = $ServiceDescription
            Dependencies    = $ServiceDependencies
        }
    }
}
