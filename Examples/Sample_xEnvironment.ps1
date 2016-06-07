Configuration xEnvironmentExample 
{
    param ()

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xEnvironment EnvironmentExample
    {
        Ensure = "Present"  # You can also set Ensure to "Absent"
        Name = "TestEnvironmentVariable"
        Value = "TestValue"
    }
}
