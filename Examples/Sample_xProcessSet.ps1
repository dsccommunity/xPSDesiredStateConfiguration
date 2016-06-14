Configuration xProcessSetExample
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xProcessSet ProcessSet1
    {
        Path = @("C:\Windows\System32\cmd.exe", "C:\Windows\System32\Notepad.exe")
        Ensure = "Present"
    }
}
