#region HEADER
# Integration Test Config Template Version: 1.2.0
#endregion

<#
    .SYNOPSIS
        Integration test configuration that uploads a file or folder
        containined in the SourcePath into the SMB Share in the DestinationPath.
#>
Configuration xFileUpload_Config
{
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'

    node $AllNodes.NodeName
    {
        xFileUpload Integration_Test
        {
            DestinationPath = $Node.DestinationPath
            SourcePath      = $Node.SourcePath
        }
    }
}
