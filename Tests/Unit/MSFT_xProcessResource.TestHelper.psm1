Import-Module "$PSScriptRoot\..\CommonTestHelper.psm1"

<#
    .SYNOPSIS
    Stops all instances of a process using the process name.
#>
function Stop-ProcessByName
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ProcessName
    )

    Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
    Wait-ScriptBlockReturnTrue -ScriptBlock {$null -eq (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)} -TimeoutSeconds 15
}

Export-ModuleMember -Function Stop-ProcessByName
