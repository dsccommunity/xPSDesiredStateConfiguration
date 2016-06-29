# Starts a set of existing stopped services

Configuration xServiceSetExample
{
    param (
        [String[]]
        $StoppedServiceNames
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xServiceSet ServiceSet1
    {
        Name = $StoppedServiceNames
        Ensure = "Present"
        State = "Running"
        StartupType = "Automatic"
        BuiltInAccount = "LocalService"
    }
}
