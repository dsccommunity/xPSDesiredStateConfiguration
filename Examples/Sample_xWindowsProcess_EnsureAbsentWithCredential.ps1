Configuration Sample_xWindowsProcess_EnsureAbsentWithCredential
{
    param
    (
        [pscredential]$cred = (Get-Credential)
    )
    Import-DSCResource -ModuleName xPSDesiredStateConfiguration
    Node localhost
    {
        xWindowsProcess Notepad
        {
            Path = "C:\Windows\System32\Notepad.exe"
            Arguments = ""
            Credential = $cred
            Ensure = "Absent"
        }
    }
}
            
# To use the sample(s) with credentials, see blog at http://blogs.msdn.com/b/powershell/archive/2014/01/31/want-to-secure-credentials-in-windows-powershell-desired-state-configuration.aspx

