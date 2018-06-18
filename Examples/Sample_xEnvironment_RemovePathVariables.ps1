<#
    .SYNOPSIS
        Removes one or more values from the 'TestPathEnvironmentVariable' environment variable if the values exist.
        Other values of the 'TestPathEnvironmentVariable' environment variable will not be modified. In this
        example, the values 'C:\test456' and 'C:\test123' will be removed, but all other entries
        will be left intact. In this example changes are made to applied the machine and the process.
#>
Configuration Sample_xEnvironment_Path_Remove
{
    param ()

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xEnvironment RemovePathEnvironmentVariables
        {
            Name = 'TestPathEnvironmentVariable'
            Ensure = 'Absent'
            Path = $true
            Value = "C:\test456;C;\test123"
            Target = @('Process', 'Machine')
        }
    }
}

Sample_xEnvironment_Path_Remove
