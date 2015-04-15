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
            

$Config = @{
    Allnodes = @(
                    @{
                        Nodename = "localhost"
                        PSDSCAllowPlainTextPassword = $true
                    }
                )
}

Sample_xWindowsProcess_EnsureAbsentWithCredential -ConfigurationData $Config 
