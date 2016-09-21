Import-Module "$PSScriptRoot\..\ResourceSetHelper.psm1"

Configuration xWindowsOptionalFeatureSet
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure,

        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Source,

        [System.Boolean]
        $RemoveFilesOnDisable,

        [ValidateNotNullOrEmpty()]
        [System.String]
        $LogPath,

        [System.Boolean]
        $NoWindowsUpdateCheck,

        [ValidateSet('ErrorsOnly', 'ErrorsAndWarning', 'ErrorsAndWarningAndInformation')]
        [System.String]
        $LogLevel
    )

    $commonParameterNames = @("Ensure", "Source", "RemoveFilesOnDisable", "LogPath", "NoWindowsUpdateCheck", "LogLevel")
    $keyParameterName = "Name"
    $resourceName = "xWindowsOptionalFeature"

    # Build common parameters for all xWindowsOptionalFeature resource nodes
    [string] $commonParameters = New-ResourceCommonParameterString -KeyParameterName $keyParameterName -CommonParameterNames $commonParameterNames -Parameters $PSBoundParameters

    # Build xWindowsOptionalFeature resource string
    [string] $resourceString = New-ResourceString -KeyParameterValues $PSBoundParameters[$keyParameterName] -KeyParameterName $keyParameterName -CommonParameters $commonParameters -ResourceName $resourceName

    $configurationScript = [ScriptBlock]::Create($resourceString)
    . $configurationScript
}
