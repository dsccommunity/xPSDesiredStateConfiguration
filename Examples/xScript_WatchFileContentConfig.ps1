
<#PSScriptInfo
.VERSION 1.0.0
.GUID f9306ebe-8af5-4dee-baf3-f3fac17891db
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/PowerShell/xPSDesiredStateConfiguration/blob/master/LICENSE
.PROJECTURI https://github.com/PowerShell/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES xPSDesiredStateConfiguration
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -module @{ModuleName = 'xPSDesiredStateConfiguration';ModuleVersion = '8.2.0.0'}

<#
    .SYNOPSIS
        Creates a file at the given file path with the specified content through
        the xScript resource.

    .DESCRIPTION
        Creates a file at the given file path with the specified content through
        the xScript resource.

    .PARAMETER FilePath
        The path at which to create the file. Defaults to $env:TEMP.

    .PARAMETER FileContent
        The content to set for the new file.
        Defaults to 'Just some sample text to write to the file'.
#>
Configuration xScript_WatchFileContentConfig {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $FilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $FileContent
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xScript ScriptExample
        {
            SetScript  = {
                $streamWriter = New-Object -TypeName 'System.IO.StreamWriter' -ArgumentList @( $using:FilePath )
                $streamWriter.WriteLine($using:FileContent)
                $streamWriter.Close()
            }

            TestScript = {
                if (Test-Path -Path $using:FilePath)
                {
                    $fileContent = Get-Content -Path $using:filePath -Raw
                    return $fileContent -eq $using:FileContent
                }
                else
                {
                    return $false
                }
            }

            GetScript  = {
                $fileContent = $null

                if (Test-Path -Path $using:FilePath)
                {
                    $fileContent = Get-Content -Path $using:filePath -Raw
                }

                return @{
                    Result = $fileContent
                }
            }
        }
    }
}

