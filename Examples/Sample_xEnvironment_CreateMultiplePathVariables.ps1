<#
    .SYNOPSIS
        Modifies the Path environment variable and sets the value to include
        both "C:\test123" and "C:\test456". If one or both of these values do not exist
        in the PATH environment variable, they will be appended. Ensure that Path is
        set to $true in order to append/remove values and not completely
        replace the Path environment variable.

#>
Configuration Sample_xEnvironment_CreateMultiplePathVariables 
{
    param ()

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xEnvironment CreateMultiplePathEnvironmentVariables
        {
            Name = 'Path'
            Value = 'C:\test123;C:\test456;C:\test789'
            Ensure = 'Present'
            Path = $true
            Target = @('Process', 'Machine')
        }
    }
}

Sample_xEnvironment_CreateMultiplePathVariables
