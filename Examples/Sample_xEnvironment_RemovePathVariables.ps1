<#
    .SYNOPSIS
        Removes one or more values from the Path environment variable if they exist.
        Other values of the Path environment variable will not be modified. In this
        example, C:\test456 and C:\test123 will be removed, but all other Path entries
        would be left intact. Ensure that Path is set to $true in order to append/remove
        values and not completely replace the Path environment variable.
#>
Configuration Sample_xEnvironment_Remove 
{
    param ()

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    Node localhost
    {
        xEnvironment RemovePathEnvironmentVariables
        {
            Name = 'Path'
            Ensure = 'Absent'
            Path = $true
            Value = "C:\test456;C;\test123"
            Target = @('Process', 'Machine')
        }
    }
}

Sample_xEnvironment_Remove
