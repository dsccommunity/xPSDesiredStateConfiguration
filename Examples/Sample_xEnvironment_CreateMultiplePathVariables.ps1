<#
    .SYNOPSIS
        Ensures that the 'TestPathEnvironmentVariable' environment variable exists and that
        its value includes both "C:\test123" and "C:\test456". If one or both of these values do not exist
        in the environment variable, they will be appended without modifying any preexisting values.
        In this example changes are made to both the machine and the process.

#>
Configuration Sample_xEnvironment_CreateMultiplePathVariables
{
    param ()

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xEnvironment CreateMultiplePathEnvironmentVariables
        {
            Name = 'TestPathEnvironmentVariable'
            Value = 'C:\test123;C:\test456;C:\test789'
            Ensure = 'Present'
            Path = $true
            Target = @('Process', 'Machine')
        }
    }
}

Sample_xEnvironment_CreateMultiplePathVariables
