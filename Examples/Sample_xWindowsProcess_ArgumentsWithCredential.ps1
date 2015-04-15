Configuration Sample_xWindowsProcess_ArgumentsWithCredential
{
    param
    (
        [pscredential]$cred = (Get-Credential)
    )
    Import-DSCResource -ModuleName xPSDesiredStateConfiguration
    Node localhost
    {
        xWindowsProcess powershell
        {
            Path = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
            Arguments = "-NoExit -file `"c:\testScript.ps1`""
            Credential = $cred
            Ensure = "Present"
        }
    }
}
            
# To use the sample(s) with credentials, see blog at http://blogs.msdn.com/b/powershell/archive/2014/01/31/want-to-secure-credentials-in-windows-powershell-desired-state-configuration.aspx

