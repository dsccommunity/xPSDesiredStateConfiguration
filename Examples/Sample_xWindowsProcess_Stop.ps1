<#
    .SYNOPSIS
        Stops the gpresult process if it is running.
#>
Configuration Sample_xWindowsProcess_Stop
{
    param
    ()

    Import-DSCResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xWindowsProcess GPresult
        {
            Path = 'C:\Windows\System32\gpresult.exe'
            Arguments = '/h C:\gp2.htm'
            Ensure = 'Absent'
        }
    }
}
 
Sample_xWindowsProcess_Stop

