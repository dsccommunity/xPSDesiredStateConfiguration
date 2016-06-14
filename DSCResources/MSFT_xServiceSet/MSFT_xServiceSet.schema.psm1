Import-Module "$PSScriptRoot\..\ResourceSetHelper.psm1"

Configuration xServiceSet
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name,

        [ValidateSet('Automatic', 'Manual', 'Disabled')]
        [System.String]
        $StartupType,

        [ValidateSet('LocalSystem', 'LocalService', 'NetworkService')]
        [System.String]
        $BuiltInAccount,

        [ValidateSet('Running', 'Stopped')]
        [System.String]
        $State,

        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    $commonParameterNames = @("StartupType", "BuiltInAccount", "State", "Ensure", "Credential")
    $keyParameterName = "Name"
    $resourceName = "xService"

    # Build common parameters for all xService resource nodes
    [string] $commonParameters = New-ResourceCommonParameterString -KeyParameterName $keyParameterName -CommonParameterNames $commonParameterNames -Parameters $PSBoundParameters

    # Build xService resource string
    [string] $resourceString = New-ResourceString -KeyParameterValues $PSBoundParameters[$keyParameterName] -KeyParameterName $keyParameterName -CommonParameters $commonParameters -ResourceName $resourceName

    $configurationScript = [ScriptBlock]::Create($resourceString)
    . $configurationScript
}
