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
            

$Config = @{
    Allnodes = @(
                    @{
                        Nodename = "localhost"
                        PSDSCAllowPlainTextPassword = $true
                    }
                )
}

Sample_xWindowsProcess_WithCredential -ConfigurationData $Config 
