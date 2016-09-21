Configuration MSFT_xServiceResource_Remove_Config {
    param
    (
        $ServiceName
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    node localhost {
        xService RemoveService {
            Name            = $ServiceName
            Ensure          = 'Absent'
        }
    }
}
