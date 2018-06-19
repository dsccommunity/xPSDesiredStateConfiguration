<#
    .SYNOPSIS
        Ensures that the DHCP Client and Windows Firewall services are running.
#>
Configuration Sample_xServiceSet_StartServices
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xServiceSet ServiceSet1
        {
            Name   = @( 'Dhcp', 'MpsSvc' )
            Ensure = 'Present'
            State  = 'Running'
        }
    }
}
