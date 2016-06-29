Import-Module "$PSScriptRoot\..\ResourceSetHelper.psm1"

Configuration xGroupSet
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $GroupName,

        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure,

        [System.String[]]
        $MembersToInclude,

        [System.String[]]
        $MembersToExclude,

        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    $commonParameterNames = @("Ensure", "MembersToInclude", "MembersToExclude", "Credential")
    $keyParameterName = "GroupName"
    $resourceName = "xGroup"

    # Build common parameters for all xGroup resource nodes
    [string] $commonParameters = New-ResourceCommonParameterString -KeyParameterName $keyParameterName -CommonParameterNames $commonParameterNames -Parameters $PSBoundParameters

    # Build xGroup resource string
    [string] $resourceString = New-ResourceString -KeyParameterValues $PSBoundParameters[$keyParameterName] -KeyParameterName $keyParameterName -CommonParameters $commonParameters -ResourceName $resourceName

    $configScript = [ScriptBlock]::Create($resourceString)
    . $configScript
}
