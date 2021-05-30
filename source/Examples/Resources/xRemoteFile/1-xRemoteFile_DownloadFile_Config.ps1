<#PSScriptInfo
.VERSION 1.0.1
.GUID bf0cf053-65d3-4d1c-a1ca-762dd2b67f9b
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/xPSDesiredStateConfiguration/blob/main/LICENSE
.PROJECTURI https://github.com/dsccommunity/xPSDesiredStateConfiguration
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -Module xPSDesiredStateConfiguration

<#
    .DESCRIPTION
        Configuration that downloads a file.

    .PARAMETER DestinationPath
        The path where the remote file should be downloaded

    .PARAMETER Uri
        The URI of the file which should be downloaded. It must be a HTTP, HTTPS
        or FILE resource.

    .PARAMETER UserAgent
        The user agent string for the web request.

    .PARAMETER Headers
        The headers of the web request.

    .EXAMPLE
        xRemoteFile_DownloadFile_Config -DestinationPath "$env:SystemDrive\fileName.jpg" -Uri 'http://www.contoso.com/image.jpg' -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer -Headers @{'Accept-Language' = 'en-US'}

        Compiles a configuration that downloads the file 'http://www.contoso.com/image.jpg'
        to the local file "$env:SystemDrive\fileName.jpg".

    .EXAMPLE
        $configurationParameters = @{
            DestinationPath = "$env:SystemDrive\fileName.jpg"
            Uri = 'http://www.contoso.com/image.jpg'
            UserAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer
            Headers = @{
                'Accept-Language' = 'en-US'
            }
        }
        Start-AzureRmAutomationDscCompilationJob -ResourceGroupName '<resource-group>' -AutomationAccountName '<automation-account>' -ConfigurationName 'xRemoteFile_DownloadFileConfig' -Parameters $configurationParameters

        Compiles a configuration in Azure Automation that downloads the file
        'http://www.contoso.com/image.jpg' to the local file
        "$env:SystemDrive\fileName.jpg".

        Replace the <resource-group> and <automation-account> with correct values.
#>
configuration xRemoteFile_DownloadFile_Config
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri,

        [Parameter()]
        [System.String]
        $UserAgent,

        [Parameter()]
        [System.Collections.Hashtable]
        $Headers
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node localhost
    {
        xRemoteFile DownloadFile
        {
            DestinationPath = $DestinationPath
            Uri             = $Uri
            UserAgent       = $UserAgent
            Headers         = $Headers
        }
    }
}
