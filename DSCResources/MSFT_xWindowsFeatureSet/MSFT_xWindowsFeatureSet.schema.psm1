Import-Module "$PSScriptRoot\..\ResourceSetHelper.psm1"

Configuration xWindowsFeatureSet
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name,

        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure,

        [ValidateNotNullOrEmpty()]
        [System.String]
        $Source,

        [System.Boolean]
        $IncludeAllSubFeature,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [ValidateNotNullOrEmpty()]
        [System.String]
        $LogPath
    )

    $commonParameterNames = @("Ensure", "Source", "IncludeAllSubFeature", "Credential", "LogPath")
    $keyParameterName = "Name"
    $resourceName = "WindowsFeature"

    # Build common parameters for all xWindowsFeature resource nodes
    [string] $commonParameters = New-ResourceCommonParameterString -KeyParameterName $keyParamName -CommonParameterNames $commonParameterNames -Parameters $PSBoundParameters
    
    # Build xWindowsFeature resource string
    [string] $resourceString = New-ResourceString -KeyParameterValues $PSBoundParameters[$keyParameterName] -KeyParameterName $keyParameterName -CommonParameters $commonParameters -ResourceName $resourceName

    $configurationScript = [scriptblock]::Create($resourceString)
    . $configurationScript
}