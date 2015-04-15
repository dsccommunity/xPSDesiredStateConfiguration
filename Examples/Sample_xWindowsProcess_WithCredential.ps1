Configuration Sample_xWindowsProcess_WithCredential
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
            Ensure = "Present"
        }
    }
}

# To use the sample(s) with credentials, see blog at http://blogs.msdn.com/b/powershell/archive/2014/01/31/want-to-secure-credentials-in-windows-powershell-desired-state-configuration.aspx

