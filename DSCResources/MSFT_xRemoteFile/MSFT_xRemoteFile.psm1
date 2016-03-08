data localizedData
{
    # culture="en-US"
    ConvertFrom-StringData @'
InvalidWebUriError=Specified URI is not valid: "{0}". Only http and https paths are accepted.
InvalidDestinationPathSchemeError=Specified DestinationPath is not valid: "{0}". DestinationPath should be absolute path.
DestinationPathIsUncError=Specified DestinationPath is not valid: "{0}". DestinationPath should be local path instead of UNC path.
DestinationPathHasInvalidCharactersError=Specified DestinationPath is not valid: "{0}". DestinationPath should be contains following characters: * ? " < > |
DestinationPathEndsWithInvalidCharacterError=Specified DestinationPath is not valid: "{0}". DestinationPath should not end with / or \\
'@
}

# Path where cache will be stored. It's cleared whenever LCM gets new configuration.
$script:cacheLocation = "$env:ProgramData\Microsoft\Windows\PowerShell\Configuration\BuiltinProvCache\MSFT_xRemoteFile"

# The Get-TargetResource function is used to fetch the status of file specified in DestinationPath on the target machine.
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri
    )    
    
    # Check whether DestinationPath is existing file
    $fileExists = $false
    $pathItemType = Get-PathItemType -path $DestinationPath
    switch($pathItemType)
    {
        "File" {
            Write-Verbose "DestinationPath: '$DestinationPath' is existing file on the machine"
            $fileExists = $true
        }

        "Directory" {
            Write-Verbose "DestinationPath: '$DestinationPath' is existing directory on the machine"
            
            # If it's existing directory, let's check whether expectedDestinationPath exists
            $uriFileName = Split-Path $Uri -Leaf
            $expectedDestinationPath = Join-Path $DestinationPath $uriFileName
            if (Test-Path $expectedDestinationPath) {
                Write-Verbose "File $uriFileName exists in DestinationPath"
                $fileExists = $true
            }
        }

        "Other" {
            Write-Verbose "DestinationPath: '$DestinationPath' has unknown type: '$pathItemType'"
        }

        "NotExists" {
            Write-Verbose "DestinationPath: '$DestinationPath' doesn't exist on the machine"
        }
    }
    
    $ensure = "Absent"
    if ($fileExists)
    {
        $ensure = "Present"
    }

    $returnValue = @{
        DestinationPath = $DestinationPath
        Ensure = $ensure    
    }

    $returnValue
}

# The Set-TargetResource function is used to download file found under Uri location to DestinationPath
# Additional parameters can be specified to configure web request
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri,        

        [System.String]
        $UserAgent,

        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Headers,

        [System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory = $false)]
        [System.Boolean]
        $MatchSource = $true
    )

    # Validate Uri
    if (!(Check-UriScheme -uri $Uri -scheme "http") -and !(Check-UriScheme -uri $Uri -scheme "https"))
    {
        $errorId = "UriValidationFailure"; 
        $errorMessage = $($LocalizedData.InvalidWebUriError) -f ${Uri} 
        Throw-InvalidDataException -errorId $errorId -errorMessage $errorMessage
    }

    # Validate DestinationPath scheme
    if (!(Check-UriScheme -uri $DestinationPath -scheme "file"))
    {
        $errorMessage = $($LocalizedData.InvalidDestinationPathSchemeError) -f ${DestinationPath} 
        Throw-InvalidDataException -errorId "DestinationPathSchemeValidationFailure" -errorMessage $errorMessage
    }

    # Validate DestinationPath is not UNC path
    if ($DestinationPath.StartsWith("\\"))
    { 
        $errorMessage = $($LocalizedData.DestinationPathIsUncError) -f ${DestinationPath} 
        Throw-InvalidDataException -errorId "DestinationPathIsUncFailure" -errorMessage $errorMessage
    }

    # Validate DestinationPath does not contain invalid characters
    $invalidCharacters = '*','?','"','<','>','|'
    $invalidCharacters | % { 
        if ($DestinationPath.Contains($_) ){
            $errorMessage = $($LocalizedData.DestinationPathHasInvalidCharactersError) -f ${DestinationPath} 
            Throw-InvalidDataException -errorId "DestinationPathHasInvalidCharactersError" -errorMessage $errorMessage
        }
    }

    # Validate DestinationPath does not end with / or \ (Invoke-WebRequest requirement)
    if ($DestinationPath.EndsWith('/') -or $DestinationPath.EndsWith('\')){
        $errorMessage = $($LocalizedData.DestinationPathEndsWithInvalidCharacterError) -f ${DestinationPath} 
        Throw-InvalidDataException -errorId "DestinationPathEndsWithInvalidCharacterError" -errorMessage $errorMessage
    }

    # Check whether DestinationPath's parent directory exists. Create if it doesn't.
    $destinationPathParent = Split-Path $DestinationPath -Parent
    if (!(Test-Path $destinationPathParent))
    {
        New-Item -Type Directory -Path $destinationPathParent -Force
    }
    
    # Check whether DestinationPath's leaf is an existing folder
    $uriFileName = Split-Path $Uri -Leaf
    if (Test-Path $DestinationPath -PathType Container)
    {
        $DestinationPath = Join-Path $DestinationPath $uriFileName        
    }

    # Remove DestinationPath and MatchSource from parameters as they are not parameters of Invoke-WebRequest
    $PSBoundParameters.Remove("DestinationPath") | Out-Null;
    $PSBoundParameters.Remove("MatchSource") | Out-Null;
    
    # Convert headers to hashtable
    $PSBoundParameters.Remove("Headers") | Out-Null;
    $headersHashtable = $null

    if ($Headers -ne $null)
    {
        $headersHashtable = Convert-KeyValuePairArrayToHashtable -array $Headers
    }    

    # Invoke web request
    try
    {
        Write-Verbose "Downloading $Uri to $DestinationPath"
        Invoke-WebRequest @PSBoundParameters -Headers $headersHashtable -outFile $DestinationPath
    }
    catch [System.OutOfMemoryException]
    {
        throw "Received OutOfMemoryException. Possible cause is the requested file being too big. $_"
    }
    catch [System.Exception]
    {
        throw "Invoking web request failed with error $($_.Exception.Response.StatusCode.Value__): $($_.Exception.Response.StatusDescription)"
    }
    
    # Update cache
    if (Test-Path $DestinationPath)
    {
        $downloadedFile = Get-Item $DestinationPath
        $lastWriteTime = $downloadedFile.LastWriteTimeUtc
        $inputObject = @{}
        $inputObject["LastWriteTime"] = $lastWriteTime
        Update-Cache -DestinationPath $DestinationPath -Uri $Uri -InputObject $inputObject
    }     
}

# The Test-TargetResource function is used to validate if the DestinationPath exists on the machine.
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri,        

        [System.String]
        $UserAgent,

        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Headers,

        [System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory = $false)]
        [System.Boolean]
        $MatchSource = $true
    )

    # Check whether DestinationPath points to existing file or directory
    $fileExists = $false
    $uriFileName = Split-Path $Uri -Leaf
    $pathItemType = Get-PathItemType -path $DestinationPath
    switch($pathItemType)
    {
        "File" {
            Write-Debug "DestinationPath: '$DestinationPath' is existing file on the machine"

            if ($MatchSource) {           
                $file = Get-Item $DestinationPath
                # Getting cache. It's cleared every time user runs Start-DscConfiguration
                $cache = Get-Cache -DestinationPath $DestinationPath -Uri $Uri

                if ($cache -ne $null -and ($cache.LastWriteTime -eq $file.LastWriteTimeUtc))
                {
                    Write-Debug "Cache reflects current state. No need for downloading file."
                    $fileExists = $true
                }
                else
                {
                    Write-Debug "Cache is empty or it doesn't reflect current state. File will be downloaded."
                }
            } else {
                Write-Debug "MatchSource is false. No need for downloading file."
                $fileExists = $true 
            }
        }

        "Directory" {
            Write-Debug "DestinationPath: '$DestinationPath' is existing directory on the machine"
            $expectedDestinationPath = Join-Path $DestinationPath $uriFileName
            
            if (Test-Path $expectedDestinationPath) {
                if ($MatchSource) { 
                    $file = Get-Item $expectedDestinationPath
                    $cache = Get-Cache -DestinationPath $expectedDestinationPath -Uri $Uri
                    if ($cache -ne $null -and ($cache.LastWriteTime -eq $file.LastWriteTimeUtc))
                    {
                        Write-Debug "Cache reflects current state. No need for downloading file."
                        $fileExists = $true
                    }
                    else
                    {
                        Write-Debug "Cache is empty or it doesn't reflect current state. File will be downloaded."
                    }
                } else {
                    Write-Debug "MatchSource is false. No need for downloading file."
                    $fileExists = $true
                }
            }    
        }

        "Other" {
            Write-Debug "DestinationPath: '$DestinationPath' has unknown type: '$pathItemType'"
        }

        "NotExists" {
            Write-Debug "DestinationPath: '$DestinationPath' doesn't exist on the machine"
        }
    }

    $result = $fileExists

    $result
}

# Throws terminating error of category InvalidData with specified errorId and errorMessage
function Throw-InvalidDataException
{
    param(
        [parameter(Mandatory = $true)]
        [System.String] 
        $errorId,
        [parameter(Mandatory = $true)]
        [System.String]
        $errorMessage
    )
    
    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidData
    $exception = New-Object System.InvalidOperationException $errorMessage 
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
    throw $errorRecord
}

# Checks whether given URI represents specific scheme
# Most common schemes: file, http, https, ftp
# We can also specify logical expressions like: [http|https]
function Check-UriScheme
{
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $uri,
        [parameter(Mandatory = $true)]
        [System.String]
        $scheme
    )
    $newUri = $uri -as [System.URI]  
    $newUri.AbsoluteURI -ne $null -and $newUri.Scheme -match $scheme
}

# Gets type of the item which path points to. 
# Returns: File, Directory, Other or NotExists
function Get-PathItemType
{
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $path
    )

    $type = $null

    # Check whether path exists
    if (Test-Path $path) 
    {
        # Check type of the path
        $pathItem = Get-Item $path
        $pathItemType = $pathItem.GetType().Name
        if ($pathItemType -eq "FileInfo")
        {
            $type = "File"
        }
        elseif ($pathItemType -eq "DirectoryInfo")
        {
            $type = "Directory"
        }
        else
        {
            $type = "Other"
        }
    }
    else 
    {
        $type = "NotExists"
    }

    return $type
}

# Converts CimInstance array of type KeyValuePair to hashtable
function Convert-KeyValuePairArrayToHashtable
{
    param (
        [parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $array
    )

    $hashtable = @{}
    foreach($item in $array)
    {
        $hashtable += @{$item.Key = $item.Value}
    }

    return $hashtable
}

# Gets cache for specific DestinationPath and Uri
function Get-Cache
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri
    )

    $cacheContent = $null
    $key = Get-CacheKey -DestinationPath $DestinationPath -Uri $Uri
    $path = Join-Path $script:cacheLocation $key
    
    Write-Debug "Looking for path $path"
    if(!(Test-Path $path))
    {
        Write-Debug "No cache found for DestinationPath = $DestinationPath and Uri = $Uri. CacheKey = $key"
        $cacheContent = $null
    }
    else
    {
        $cacheContent = Import-CliXml $path
        Write-Debug "Found cache for DestinationPath = $DestinationPath and Uri = $Uri. CacheKey = $key"
    }

    return $cacheContent
}

# Creates or updates cache for specific DestinationPath and Uri
function Update-Cache
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri,
        
        [parameter(Mandatory = $true)]
        [Object]
        $InputObject
    )

    $key = Get-CacheKey -DestinationPath $DestinationPath -Uri $Uri
    $path = Join-Path $script:cacheLocation $key
    
    if(-not (Test-Path $script:cacheLocation))
    {
        mkdir $script:cacheLocation | Out-Null
    }

    Write-Debug "Updating cache for DestinationPath = $DestinationPath and Uri = $Uri. CacheKey = $key"
    Export-CliXml -Path $path -InputObject $InputObject -Force
}

# Returns cache key for given parameters
function Get-CacheKey
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Uri
    )
    $key = [string]::Join("", @($DestinationPath, $Uri)).GetHashCode().ToString()
    return $key
}

Export-ModuleMember -Function *-TargetResource



