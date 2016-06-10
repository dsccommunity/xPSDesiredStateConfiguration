Set-StrictMode -version Latest

<#
    .SYNOPSIS
    Builds a string with all common parameters shared across all resource nodes.
#>
function New-ResourceCommonParameterString
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $KeyParameterName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $CommonParameterNames,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $Parameters
    )

    [System.Text.StringBuilder] $stringBuilder = New-Object System.Text.StringBuilder

    # Build optional parameters for invoking the inbuilt resource
    foreach ($parameterName in $Parameters.Keys) 
    {
        if ($parameterName -ne $KeyParameterName -and $parameterName -in $CommonParameterNames)
        {
            $parameterValue = $Parameters[$parameterName]
            if ($null -ne $parameterValue)
            {
                if ($parameterValue -is [System.String])
                {
                    $stringBuilder.AppendFormat('{0} = "{1}"', $parameterName, $parameterValue) | Out-Null
                    $stringBuilder.AppendLine() | Out-Null
                }
                else
                {
                    $stringBuilder.Append($parameterName + ' = $' + $parameterName) | Out-Null
                    $stringBuilder.AppendLine() | Out-Null
                }
            }
        }
    }

    return $stringBuilder.ToString()
}

<#
    .SYNOPSIS
    Builds a string with all resource nodes.

    .DESCRIPTION
    Builds a string with all resource nodes based on the key parameter along with the other optional parameters provided in the composite configuration. 
    For example, while installing multiple features using WindowsFeature resource, output of this method would be:
        $KeyParam = @("Telnet-client","web-server")
        WindowsFeature Resource0
        {
        Name = "Telnet-client" #Name provided in the composite configuration
        Ensure = "Present"
        IncludeAllSubFeature = True
        }  

        WindowsFeature Resource1
        {
        Name = "Web-Server" #Name provided in the composite configuration
        Ensure = "Present"
        IncludeAllSubFeature = True
        }
#>
function New-ResourceString
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $KeyParameterValues, 
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $KeyParameterName,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $CommonParameters,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ResourceName,

        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleName = "xPSDesiredStateConfiguration",

        [ValidateNotNullOrEmpty()]
        [string]
        $DefaultParameters
    )

    [System.Text.StringBuilder] $stringBuilder = New-Object System.Text.StringBuilder

    $stringBuilder.AppendFormat('Import-DscResource -Name {0} -ModuleName {1}', $ResourceName, $ModuleName) | Out-Null
    $stringBuilder.AppendLine() | Out-Null

    # Add the resource nodes and their common parameters
    [int] $resourceCount = 0
    foreach ($keyParameterValue in $KeyParameterValues)
    {
        $stringBuilder.AppendFormat('{0} Resource{1}', $ResourceName, $resourceCount) | Out-Null
        $stringBuilder.AppendLine() | Out-Null
        $stringBuilder.AppendLine('{') | Out-Null
        $stringBuilder.AppendFormat($KeyParameterName + ' = "{0}"', $keyParameterValue) | Out-Null
        $stringBuilder.AppendLine() | Out-Null
        $stringBuilder.AppendLine($CommonParameters) | Out-Null
        
        if ($DefaultParameters)
        {
            $stringBuilder.AppendLine($DefaultParameters) | Out-Null
        }

        $stringBuilder.AppendLine('}') | Out-Null
        $resourceCount++
    }

    return $stringBuilder.ToString()
}

Export-ModuleMember -Function `
    New-ResourceCommonParameterString, `
    New-ResourceString
