<#
    .SYNOPSIS
    Tests that the Get-TargetResource method of a DSC Resource is not null, can be converted to a hashtable, and has the correct properties.
    Uses Pester.

    .PARAMETER GetTargetResourceResult
    The result of the Get-TargetResource method.

    .PARAMETER GetTargetResourceResultProperties
    The properties that the result of Get-TargetResource should have.
#>
function Test-GetTargetResourceResult
{
    [CmdletBinding()]
    param (
        $GetTargetResourceResult,

        [string[]]
        $GetTargetResourceResultProperties
    )

    $getTargetResourceResultHashtable = $GetTargetResourceResult -as [Hashtable]

    $getTargetResourceResultHashtable | Should Not Be $null

    foreach ($property in $GetTargetResourceResultProperties) 
    {
        $getTargetResourceResultHashtable[$property] | Should Not Be $null
    }
}

Export-ModuleMember -Function `
    Test-GetTargetResourceResult
