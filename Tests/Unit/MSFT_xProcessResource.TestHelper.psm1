<#
    .SYNOPSIS
    Waits for a script block to complete execution.
#>
function Wait-ScriptBlock
{
    [CmdletBinding()]
    param (
        [ScriptBlock]
        $ScriptBlock,

        [Int]
        $TimeoutSeconds = 5
    )

    $startTime = [DateTime]::Now

    $invokeScriptBlockResult = $false
    while (-not $invokeScriptBlockResult -and (([DateTime]::Now - $startTime).TotalSeconds -lt $TimeoutSeconds))
    {
        $invokeScriptBlockResult = $ScriptBlock.Invoke()
        Start-Sleep -Seconds 1
    }

    return $invokeScriptBlockResult
}

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
    Wait-ScriptBlock -ScriptBlock {$null -eq (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)} -TimeoutSeconds 15
}

Export-ModuleMember -Function Stop-ProcessByName
