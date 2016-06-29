Configuration xWindowsFeatureExample
{
    Import-DSCResource -ModuleName xPSDesiredStateConfiguration

    xWindowsFeature RoleExample
    {
        Ensure = "Present" # Alternatively, to ensure the role is uninstalled, set Ensure to "Absent"
        Name = "Web-Server" # Use the Name property from Get-WindowsFeature  
    }
}
