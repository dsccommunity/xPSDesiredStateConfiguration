data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData @'
    InvalidChecksumArgsMessage=Specifying a Checksum without requesting content validation (the Validate parameter) is not meaningful
    InvalidDestinationDirectory=The specified destination directory {0} does not exist or is not a directory
    InvalidSourcePath=The specified source file {0} does not exist or is not a file
    ErrorOpeningExistingFile=An error occurred while opening the file {0} on disk. Please examine the inner exception for details
    ErrorOpeningArchiveFile=An error occurred while opening the archive file {0}. Please examine the inner exception for details
    ItemExistsButIsWrongType=The named item ({0}) exists but is not the expected type, and Force was not specified
    ItemExistsButIsIncorrect=The destination file {0} has been determined not to match the source, but Force has not been specified. Cannot continue
    ErrorCopyingToOutstream=An error was encountered while copying the archived file to {0}
    PackageUninstalled=The archive at {0} was removed from destination {1}
    PackageInstalled=The archive at {0} was unpacked to destination {1}
    ConfigurationStarted=The configuration of MSFT_ArchiveResource is starting
    ConfigurationFinished=The configuration of MSFT_ArchiveResource has completed
    MakeDirectory=Make directory {0}
    RemoveFileAndRecreateAsDirectory=Remove existing file {0} and replace it with a directory of the same name
    RemoveFile=Remove file {0}
    RemoveDirectory=Remove directory {0}
    UnzipFile=Unzip archived file to {0}
    DestMissingOrIncorrectTypeReason=The destination file {0} was missing or was not a file
    DestHasIncorrectHashvalue=The destination file {0} exists but its checksum did not match the origin file
    DestShouldNotBeThereReason=The destination file {0} exists but should not
    PathNotFoundError=The path {0} either does not exist or is not a valid file system path.
    InvalidZipFileExtensionError={0} is not a supported archive file format. {1} is the only supported archive file format.
    ZipFileExistError=The archive file {0} already exists. If you want to update the existing archive file, run the same command with -Update switch parameter.
    InvalidPathForExpandError=The input to Path parameter {0} contains multiple file system paths. When DestinationType is set to Directory, the Path parameter can accept only one path to the archive file which would be expanded to the path specified by Destination parameter.
    InvalidDirZipFileExtensionError={0} is a directory path. The destination path needs to be a path to an archive file. {1} is the only supported archive file format.
    DuplicatePathFoundError=The input to {0} parameter contains a duplicate path '{1}'. Provide a unique set of paths as input to {2} parameter.
'@
}

Import-LocalizedData  LocalizedData -filename ArchiveResources

$compressCacheLocation = "$env:ProgramData\Microsoft\PSDesiredStateConfiguration\DSCResources\xArchive\Cache"
$CompressionLevelString = "CompressionLevel"
$FileCountString = "FileCount"
$DirectoryCountString = "DirectoryCount"
$LastWriteTimeUtcString = "LastWriteTimeUtc"

# Begin Expand CodeBase

$Debug = $false
Function Trace-Message
{
    param([string] $Message)
    if($Debug)
    {
        Write-Verbose $Message
    }
}

$CacheLocation = "$env:systemroot\system32\Configuration\BuiltinProvCache\MSFT_ArchiveResource"


Function Get-CacheEntry
{
    $key = [string]::Join($args).GetHashCode().ToString()
    Trace-Message "Using ($key) to retrieve hash value"
    $path = Join-Path $CacheLocation $key
    if(-not (Test-Path $path))
    {
        Trace-Message "No cache value found"
        return @{}
    }
    else
    {
        $tmp = Import-CliXml $path
        Trace-Message "Cache value found, returning $tmp"
        return $tmp
    }
}

Function Set-CacheEntry
{
    param([object] $InputObject)
    $key = [string]::Join($args).GetHashCode().ToString()
    Trace-Message "Using $tmp ($key) to save hash value"
    $path = Join-Path $CacheLocation $key
    Trace-Message "About to cache value $InputObject"
    if(-not (Test-Path $CacheLocation))
    {
        mkdir $CacheLocation | Out-Null
    }
    
    Export-CliXml -Path $path -InputObject $InputObject
}

Function Throw-InvalidArgumentException
{
    param(
        [string] $Message,
        [string] $ParamName
    )
    
    $exception = new-object System.ArgumentException $Message,$ParamName
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception,$ParamName,"InvalidArgument",$null
    throw $errorRecord
}

Function Throw-TerminatingError
{
    param(
        [string] $Message,
        [System.Management.Automation.ErrorRecord] $ErrorRecord,
        [string] $ExceptionType
    )
    
    $exception = new-object "System.InvalidOperationException" $Message,$ErrorRecord.Exception
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception,"MachineStateIncorrect","InvalidOperation",$null
    throw $errorRecord
}

Function Assert-ValidStandardArgs
{
    param(
        [string] $Path,
        [string] $Destination,
        [boolean] $Validate,
        [string] $Checksum
    )
    
    #mkdir and Test-Path can each fail with a useful error message
    #We want to stop our execution if that happens
    $ErrorActionPreference = "Stop"
    
    if(-not (Test-Path -PathType Leaf $Path))
    {
        Throw-InvalidArgumentException ($LocalizedData.InvalidSourcePath -f $Path) "Path"
    }
    
    $item = Get-Item -ErrorAction Ignore -LiteralPath $Destination
    if($item -and $item.GetType() -eq [System.IO.FileInfo])
    {
        Throw-InvalidArgumentException ($LocalizedData.InvalidDestinationDirectory -f $Destination) "Destination"
    }
    
    if($Checksum -and -not $Validate)
    {
        Throw-InvalidArgumentException ($LocalizedData.InvalidChecksumArgsMessage -f $Checksum) "Checksum"
    }
}

Function Get-Hash
{
    param(
        [System.IO.Stream] $Stream,
        [string] $Algorithm
    )
    
    $hashGenerator = $null
    $hashNameToType = @{
        #This is the sort of thing that normally is declared as a global constant, but referencing the type incurs cost
        #that we're trying to avoid in some cold-start cases
        "sha-1" = [System.Security.Cryptography.SHA1]
        "sha-256" = [System.Security.Cryptography.SHA256];
        "sha-512" = [System.Security.Cryptography.SHA512]
    }
    $algorithmType = $hashNameToType[$Algorithm]
    try
    {
        $hashGenerator = $algorithmType::Create() #All types in the dictionary will have this method
        [byte[]]$hashGenerator.ComputeHash($Stream)
    }
    finally
    {
        if($hashGenerator)
        {
            $hashGenerator.Dispose()
        }
    }
}

Function Compare-FileToEntry
{
    param(
        [string] $FileName,
        [object] $Entry,
        [string] $Algorithm
    )
    
    $existingStream = $null
    $hash1 = $null
    try
    {
        $existingStream = New-Object System.IO.FileStream $FileName, "Open"
        $hash1 = Get-Hash $existingStream $Algorithm
    }
    catch
    {
        Throw-TerminatingError ($LocalizedData.ErrorOpeningExistingFile -f $FileName) $_
    }
    finally
    {
        if($existingStream -ne $null)
        {
            $existingStream.Dispose()
        }
    }
    
    $hash2 = $Entry.Checksum
    for($i = 0; $i -lt $hash1.Length; $i++)
    {
        if($hash1[$i] -ne $hash2[$i])
        {
            return $false
        }
    }
    
    return $true
}

Function Get-RelevantChecksumTimestamp
{
    param(
        [System.IO.FileSystemInfo] $FileSystemObject,
        [String] $Checksum
    )
    
    if($Checksum.Equals("createddate"))
    {
        return $FileSystemObject.CreationTime
    }
    else #$Checksum.Equals("modifieddate")
    {
        return $FileSystemObject.LastWriteTime
    }
}

Function Update-Cache
{
    param(
        [Hashtable] $CacheObject,
        [System.IO.Compression.ZipArchiveEntry[]] $Entries,
        [string] $Checksum,
        [string] $SourceLastWriteTime
    )
    
    Trace-Message "In Update-Cache"
    $cacheEntries = new-object System.Collections.ArrayList
    foreach($entry in $Entries)
    {
        $hash = $null
        if($Checksum.StartsWith("sha"))
        {
            $stream = $null
            try
            {
                $stream = $entry.Open()
                $hash = Get-Hash $stream $Checksum
            }
            finally
            {
                if($stream)
                {
                    $stream.Dispose()
                }
            }
        }
        
        Trace-Message "Adding $entry.FullName as a cache entry"
        $cacheEntries.Add(@{
            FullName = $entry.FullName
            LastWriteTime = $entry.LastWriteTime
            Checksum = $hash
        }) | Out-Null
    }
    
    Trace-Message "Updating CacheObject"
    $CacheObject["SourceLastWriteTime"] = $SourceLastWriteTime
    $CacheObject["Entries"] = (@() + $cacheEntries)
    Set-CacheEntry -InputObject $CacheObject $Path $Destination
    Trace-Message "Placed new cache entry"
}

Function Normalize-Checksum
{
    param(
        [boolean] $Validate,
        [string] $Checksum
    )
    
    if($Validate)
    {
        if(-not $Checksum)
        {
            $Checksum = "SHA-256"
        }
        
        $Checksum = $Checksum.ToLower()
    }
    
    Trace-Message "Normalize-Checksum returning $Checksum"
    return $Checksum
}

# The Test-ExpandArchive cmdlet is used to test the status of item on the destination
function Test-ExpandArchive
{
    param
    (
        [ValidateSet("Present", "Absent")]
        [string] $Ensure = "Present",
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination,
        
        [boolean] $Validate = $false,
        
        [ValidateSet("", "SHA-1", "SHA-256", "SHA-512", "CreatedDate", "ModifiedDate")]
        [string] $Checksum,

        [boolean] $Force = $false
    )

    $ErrorActionPreference = "Stop"
    
    Trace-Message "About to validate standard arguments"
    Assert-ValidStandardArgs $Path $Destination $Validate $Checksum
    $Checksum = Normalize-Checksum $Validate $Checksum
    Trace-Message "Going for cache entries"
    $result = $true
    $cacheObj = Get-CacheEntry $Path $Destination
    $sourceLastWriteTime = (Get-Item -LiteralPath $Path).LastWriteTime
    $cacheUpToDate = $cacheObj -and $cacheObj.SourceLastWriteTime -and $cacheObj.SourceLastWriteTime -eq $sourceLastWriteTime
    $file = $null
    try
    {
        $entries = $null
        if($cacheUpToDate)
        {
            Trace-Message "The cache was up to date, using cache to satisfy requests"
            $entries = $cacheObj.Entries
        }
        else
        {
            Trace-Message "About to open the zip file"
            $entries, $null, $file = Open-ZipFile $Path
            
            Trace-Message "Updating cache"
            Update-Cache $cacheObj $entries $Checksum $sourceLastWriteTime
            $entries = $cacheObj.Entries
            Trace-Message ("Cache updated with {0} entries" -f $cacheObj.Entries.Length)
        }
        
        foreach($entry in $entries)
        {
            $individualResult = $true
            Trace-Message ("Processing {0}" -f $entry.FullName)
            $dest = join-path $Destination $entry.FullName
            if($dest.EndsWith('\')) #Directory
            {
                $dest = $dest.TrimEnd('\')
                if(-not (Test-Path -PathType Container $dest))
                {
                    Write-Verbose ($LocalizedData.DestMissingOrIncorrectTypeReason -f $dest)
                    $individualResult = $result = $false
                }
            }
            else
            {
                $item = Get-Item -LiteralPath $dest -ErrorAction Ignore
                if(-not $item)
                {
                    $individualResult = $result = $false
                }
                elseif($item.GetType() -ne [System.IO.FileInfo])
                {
                    $individualResult = $result = $false
                }
                
                if(-not $Checksum)
                {
                    Trace-Message "In Test-TargetResource: $dest exists, not using checksums, continuing"
                    if(-not $individualResult -and $Ensure -eq "Present")
                    {
                        Write-Verbose ($LocalizedData.DestMissingOrIncorrectTypeReason -f $dest)
                    }
                    elseif($individualResult -and $Ensure -eq "Absent")
                    {
                        Write-Verbose ($LocalizedData.DestShouldNotBeThereReason -f $dest)
                    }
                }
                else
                {
                    #If the file is there we need to check if it could possibly fail in a different way
                    #Otherwise we skip all these checks - there's nothing to work with
                    if($individualResult)
                    {
                        $Checksum = $Checksum.ToLower()
                        if($Checksum.StartsWith("sha"))
                        {
                            if($item.LastWriteTime.Equals($entry.ExistingItemTimestamp))
                            {
                                Trace-Message "Not performing checksum, the file on disk has the same write time as the last time we verified its contents"
                            }
                            else
                            {
                                if(-not (Compare-FileToEntry $dest $entry $Checksum))
                                {
                                    $individualResult = $result = $false
                                }
                                else
                                {
                                    $entry.ExistingItemTimestamp = $item.LastWriteTime
                                    Trace-Message "$dest exists and the hash matches even though the LastModifiedTime didn't (for some reason) updating cache"
                                }
                            }
                        }
                        else
                        {
                            $date = Get-RelevantChecksumTimestamp $item $Checksum
                            if(-not $date.Equals($entry.LastWriteTime.DateTime))
                            {
                                $individualResult = $result = $false
                            }
                            else
                            {
                                Trace-Message "In Test-TargetResource: $dest exists and the selected timestamp ($Checksum) matched"
                            }
                        }
                    }
                    
                    if(-not $individualResult -and $Ensure -eq "Present")
                    {
                        Write-Verbose ($LocalizedData.DestHasIncorrectHashvalue -f $dest)
                    }
                    elseif($individualResult -and $Ensure -eq "Absent")
                    {
                        Write-Verbose ($LocalizedData.DestShouldNotBeThereReason -f $dest)
                    }
                }
            }
        }
    }
    finally
    {
        if($file)
        {
            $file.Dispose()
        }
    }
    
    Set-CacheEntry -InputObject $cacheObj $Path $Destination
    $result = $result -eq ("Present" -eq $Ensure)
    return $result
}
        
Function Ensure-Directory
{
    param([string] $Dir)
    $item = Get-Item -LiteralPath $Dir -ErrorAction SilentlyContinue
    if(-not $item)
    {
        Trace-Message "Folder $Dir does not exist"
        if($PSCmdlet.ShouldProcess(($LocalizedData.MakeDirectory -f $Dir), $null, $null))
        {
            mkdir $Dir | Out-Null
        }
    }
    else
    {
        if($item.GetType() -ne [System.IO.DirectoryInfo])
        {
            if($Force -and $PSCmdlet.ShouldProcess(($LocalizedData.RemoveFileAndRecreateAsDirectory -f $Dir), $null, $null))
            {
                Trace-Message "Removing $Dir"
                rm $Dir | Out-Null
                mkdir $Dir | Out-Null #Note that we don't do access time translations onto directories since we are emulating the shell's behavior
            }
            else
            {
                Throw-TerminatingError ($LocalizedData.ItemExistsButIsWrongType -f $Path)
            }
        }
    }
}

Function Open-ZipFile
{
    param($Path)
    add-type -assemblyname System.IO.Compression.FileSystem
    $nameHash = @{}
    try
    {
        $fileHandle = ([System.IO.Compression.ZipFile]::OpenRead($Path))
        $entries = $fileHandle.Entries
    }    
    catch
    {
        Throw-TerminatingError ($LocalizedData.ErrorOpeningArchiveFile -f $Path) $_
    }
    
    $entries | %{$nameHash[$_.FullName] = $_}
    return $entries, $nameHash, $fileHandle
}

# The Set-ExpandArchive cmdlet is used to unpack or remove a zip file to a particular directory
function Set-ExpandArchive
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination,
        
        [ValidateSet("Present", "Absent")]
        [string] $Ensure = "Present",
        
        [boolean] $Validate = $false,
        
        [ValidateSet("", "SHA-1", "SHA-256", "SHA-512", "CreatedDate", "ModifiedDate")]
        [string] $Checksum,
        
        [boolean] $Force = $false
    )
    
    $ErrorActionPreference = "Stop"
    Assert-ValidStandardArgs $Path $Destination $Validate $Checksum
    $Checksum = Normalize-Checksum $Validate $Checksum
    Write-Verbose $LocalizedData.ConfigurationStarted
    
    if(-not (Test-Path $Destination))
    {
        mkdir $Destination | Out-Null
    }
    
    $cacheObj = Get-CacheEntry $Path $Destination
    $sourceLastWriteTime = (Get-Item -LiteralPath $Path).LastWriteTime
    $cacheUpToDate = $cacheObj -and $cacheObj.SourceLastWriteTime -and $cacheObj.SourceLastWriteTime -eq $sourceLastWriteTime
    $file = $null
    $nameToEntry = @{}
    try
    {
        if(-not $cacheUpToDate)
        {
            $entries, $nameToEntry, $file = Open-ZipFile $Path
            Update-Cache $cacheObj $entries $Checksum $sourceLastWriteTime
        }
        
        $entries = $cacheObj.Entries
        if($Ensure -eq "Absent")
        {
            $directories = new-object system.collections.generic.hashset[string]
            foreach($entry in $entries)
            {
                $isDir = $false
                if($entry.FullName.EndsWith("\"))
                {
                    $isDir = $true
                    $directories.Add((Split-Path -Leaf $entry)) | Out-Null
                }
                
                $parent = $entry.FullName
                while(($parent = (Split-Path $parent))) { $directories.Add($parent) | Out-Null }
                
                if($isDir)
                {
                    #Directory removal is handled as its own pass, see note and code after this loop
                    continue
                }
                
                $existing = Join-Path $Destination $entry.FullName
                $item = Get-Item -LiteralPath $existing -ErrorAction SilentlyContinue
                if(-not $item)
                {
                    continue
                }
                
                 #Possible for a folder to have been replaced by a directory of the same name, in which case we must leave it alone
                $type = $item.GetType()
                if($type -ne [System.IO.FileInfo])
                {
                    continue
                }
                
                if(-not $Checksum -and $PSCmdlet.ShouldProcess(($LocalizedData.RemoveFile -f $existing), $null, $null))
                {
                    Trace-Message "Removing $existing"
                    rm $existing
                    continue
                }
                
                $Checksum = $Checksum.ToLower()
                if($Checksum.StartsWith("sha"))
                {
                    if((Compare-FileToEntry $existing $entry $Checksum) -and $PSCmdlet.ShouldProcess(($LocalizedData.RemoveFile -f $existing), $null, $null))
                    {
                        Trace-Message "Hashes of existing and zip files match, removing"
                        rm $existing
                    }
                    else
                    {
                        Trace-Message "Hash did not match, file has been modified since it was extracted. Leaving"
                    }
                }
                else
                {
                    $date = Get-RelevantChecksumTimestamp $item $Checksum
                    if($date.Equals($entry.LastWriteTime.DateTime) -and $PSCmdlet.ShouldProcess(($LocalizedData.RemoveFile -f $existing), $null, $null))
                    {
                        Trace-Message "In Set-TargetResource: $existing exists and the selected timestamp ($Checksum) matched, removing"
                        rm $existing
                    }
                    else
                    {
                        Trace-Message "In Set-TargetResource: $existing exists and the selected timestamp ($Checksum) did not match, leaving"
                    }
                }
            }
            
            #Hashset was useful for dropping dupes in an efficient manner, but it can mess with ordering
            #Sort according to current culture (directory names can be localized, obviously)
            #Reverse so we hit children before parents
            $directories = [system.linq.enumerable]::ToList($directories)
            $directories.Sort([System.StringComparer]::InvariantCultureIgnoreCase)
            $directories.Reverse()
            foreach($directory in $directories)
            {
                Trace-Message "Examining $directory to see if it should be removed"
                $existing = Join-Path $Destination $directory
                $item = Get-Item -LiteralPath $existing -ErrorAction SilentlyContinue
                if($item -and $item.GetType() -eq [System.IO.DirectoryInfo] -and $item.GetFiles().Count -eq 0 -and $item.GetDirectories().Count -eq 0 `
                     -and $PSCmdlet.ShouldProcess(($LocalizedData.RemoveDirectory -f $existing), $null, $null))
                {
                    Trace-Message "$existing appears to be an empty directory. Removing it"
                    rmdir $existing
                }
            }
            
            Write-Verbose ($LocalizedData.PackageUninstalled -f $Path,$Destination)
            Write-Verbose $LocalizedData.ConfigurationFinished
            return
        }
        
        Ensure-Directory $Destination
        foreach($entry in $entries)
        {
            $dest = join-path $Destination $entry.FullName
            if($dest.EndsWith('\')) #Directory
            {
                Ensure-Directory $dest.TrimEnd("\") #Some cmdlets have problems with trailing char
                continue
            }
            
            $item = Get-Item -LiteralPath $dest -ErrorAction SilentlyContinue
            if($item)
            {
                if($item.GetType() -eq [System.IO.FileInfo])
                {
                    if(-not $Checksum)
                    {
                        #It exists. The user didn't specify -Validate, so that's good enough for us
                        continue
                    }
                    
                    if($Checksum.StartsWith("sha"))
                    {
                        if($item.LastWriteTime.Equals($entry.ExistingTimestamp))
                        {
                            Trace-Message "LastWriteTime of $dest matches what we have on record, not re-examining $checksum"
                        }
                        else
                        {
                            $identical = Compare-FileToEntry $dest $entry $Checksum
                            
                            if($identical)
                            {
                                Trace-Message "Found a file at $dest where we were going to place one and hash matched. Continuing"
                                $entry.ExistingItemTimestamp = $item.LastWriteTime
                                continue
                            }
                            else
                            {
                                if($Force)
                                {
                                    Trace-Message "Found a file at $dest where we were going to place one and hash didn't match. It will be overwritten"
                                }
                                else
                                {
                                    Trace-Message "Found a file at $dest where we were going to place one and does not match the source, but Force was not specified. Erroring"
                                    Throw-TerminatingError ($LocalizedData.ItemExistsButIsIncorrect -f $dest)
                                }
                            }
                        }
                    }
                    else
                    {
                        $date = Get-RelevantChecksumTimestamp $item $Checksum
                        if($date.Equals($entry.LastWriteTime.DateTime))
                        {
                            Trace-Message "In Set-TargetResource: $dest exists and the selected timestamp ($Checksum) matched, will leave it"
                            continue
                        }
                        else
                        {
                            if($Force)
                            {
                                Trace-Message "In Set-TargetResource: $dest exists and the selected timestamp ($Checksum) did not match. Force was specified, we will overwrite"
                            }
                            else
                            {
                                Trace-Message "Found a file at $dest and timestamp ($Checksum) does not match the source, but Force was not specified. Erroring"
                                Throw-TerminatingError ($LocalizedData.ItemExistsButIsIncorrect -f $dest)
                            }
                        }
                    }
                }
                else
                {
                    if($Force)
                    {
                        Trace-Message "Found a directory at $dest where a file should be. Removing"
                        if($PSCmdlet.ShouldProcess(($LocalizedData.RemoveDirectory -f $dest), $null, $null))
                        {
                            rmdir -Recurse -Force $dest
                        }
                    }
                    else
                    {
                        Trace-Message "Found a directory at $dest where a file should be and Force was not specified. Erroring."
                        Throw-TerminatingError ($LocalizedData.ItemExistsButIsWrongType -f $dest)
                    }
                }
            }
            
            $parent = Split-Path $dest
            if(-not (Test-Path $parent) -and $PSCmdlet.ShouldProcess(($LocalizedData.MakeDirectory -f $parent), $null, $null))
            {
                #TODO: This is an edge case we need to revisit. We should be correctly handling wrong file types along
                #the directory path if they occur within the archive, but they don't have to. Simple tests demonstrate that
                #the Zip format allows you to have the file within a folder without explicitly having an entry for the folder
                #This solution will fail in such a case IF anything along the path is of the wrong type (e.g. file in a place
                #we expect a directory to be)
                mkdir $parent | Out-Null
            }
            
            if($PSCmdlet.ShouldProcess(($LocalizedData.UnzipFile -f $dest), $null, $null))
            {
                #If we get here we can safely blow away anything we find.
                $null, $nameToEntry, $file = Open-ZipFile $Path
                $stream = $null
                $outStream = $null
                try
                {
                    Trace-Message "Writing to file $dest"
                    $stream = $nameToEntry[$entry.FullName].Open()
                    $outStream = New-Object System.IO.FileStream $dest, "Create"
                    $stream.CopyTo($outStream)
                }
                catch
                {
                    Throw-TerminatingError ($LocalizedData.ErrorCopyingToOutstream -f $dest) $_
                }
                finally
                {
                    if($stream -ne $null)
                    {
                        $stream.Dispose()
                    }
                    
                    if($outStream -ne $null)
                    {
                        $outStream.Dispose()
                    }
                }
                
                $fileInfo = New-Object System.IO.FileInfo $dest
                $entry.ExistingItemTimestamp = $fileInfo.LastWriteTime = $fileInfo.LastAccessTime = $fileInfo.CreationTime = $entry.LastWriteTime.DateTime
            }
        }
    }
    finally
    {
        if($file)
        {
            $file.Dispose()
        }
    }
    
    Set-CacheEntry -InputObject $cacheObj $Path $Destination
    Write-Verbose ($LocalizedData.PackageInstalled -f $Path,$Destination)
    Write-Verbose $LocalizedData.ConfigurationFinished
}

# The Get-ExpandArchive cmdlet is used to fetch the object
function Get-ExpandArchive
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination,
        
        [boolean] $Validate = $false,
        
        [ValidateSet("", "SHA-1", "SHA-256", "SHA-512", "CreatedDate", "ModifiedDate")]
        [string] $Checksum
    )
    
    $exists = Test-ExpandArchive -Path $Path -Destination $Destination -Validate $Validate -Checksum $Checksum
    
    $stringResult = "Absent"
    if($exists)
    {
        $stringResult = "Present"
    }
    
    @{
        Ensure = $stringResult;
        Path = $Path;
        Destination = $Destination;
    }
}

# End Expand CodeBase

function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [parameter(mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        [parameter (mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination,

        [parameter (mandatory=$false)]
        [ValidateSet("Optimal","NoCompression","Fastest")]
        [string]
        $CompressionLevel = "Optimal",

        [parameter (mandatory=$false)]
        [ValidateSet("File","Directory")]
        [string]
        $DestinationType = "Directory",

        [parameter (mandatory=$false)]
        [boolean]
        $MatchSource = $false
    )

   ValidateDuplicateFileSystemPath "Path" $Path
   $result = $false

   if($DestinationType -eq "File")
   {
        ValidateCompressParameters $Path $Destination $DestinationType
        $result = IsArchiveCacheUpdated $Destination $Path $MatchSource $CompressionLevel

        Write-Verbose "Test Result $result"
   }
   else
   {
        ValidateExpandParameters $Path $Destination $DestinationType
        $result = Test-ExpandArchive -Ensure "Present" -Path $Path[0] -Destination $Destination
   }

   return $result
}

function Set-TargetResource 
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        [parameter (mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination,

        [parameter (mandatory=$false)]
        [ValidateSet("Optimal","NoCompression","Fastest")]
        [string]
        $CompressionLevel = "Optimal",

        [parameter (mandatory=$false)]
        [ValidateSet("File","Directory")]
        [string]
        $DestinationType = "Directory",

        [parameter (mandatory=$false)]
        [boolean]
        $MatchSource = $false
    )
   
   ValidateDuplicateFileSystemPath "Path" $Path
 
   if($DestinationType -eq "File")
   {
        ValidateCompressParameters $Path $Destination $DestinationType

        # Delete stale archive file and its cache.
        DeleteArchiveFileAndItsCache $Destination

        # Create the archive file.
        Compress-xArchive -Path $Path -DestinationPath $Destination -CompressionLevel $CompressionLevel
        
        # Create the archive file specific cache.
        CreateArchiveCache $Destination $Path $CompressionLevel
   }
   else
   {
        ValidateExpandParameters $Path $Destination $DestinationType
        Set-ExpandArchive -Ensure "Present" -Path $Path[0] -Destination $Destination
   }
}

function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        [parameter (mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination,

        [parameter (mandatory=$false)]
        [ValidateSet("Optimal","NoCompression","Fastest")]
        [string]
        $CompressionLevel = "Optimal",

        [parameter (mandatory=$false)]
        [ValidateSet("File","Directory")]
        [string]
        $DestinationType = "Directory",

        [parameter (mandatory=$false)]
        [boolean]
        $MatchSource = $false
    )

   ValidateDuplicateFileSystemPath "Path" $Path

   if($DestinationType -eq "File")
   {
        ValidateCompressParameters $Path $Destination $DestinationType

        $currentFileInfo = New-Object -TypeName System.IO.FileInfo -ArgumentList $Destination

        if($currentFileInfo.Exists -eq $true)
        {
            $creationTime = $currentFileInfo.CreationTime
            $attributes = $currentFileInfo.Attributes.ToString()
            $size = $currentFileInfo.Length
            $mode = $currentFileInfo.Mode
        }

        $getTargetResourceResult = @{
                                        Path = $Path; 
                                        Destination = $Destination;
                                        CompressionLevel = $CompressionLevel;
                                        DestinationType = $DestinationType;
                                        MatchSource = $MatchSource;
                                        CreationTime = $creationTime;
                                        Attributes = $attributes;
                                        Size = $size;
                                        Mode = $mode;
                                    }
   }
   else
   {
        ValidateExpandParameters $Path $Destination $DestinationType
        $expandArchiveResult = Get-ExpandArchive -Path $Path[0] -Destination $Destination

        $archiveFilePath = $expandArchiveResult["Path"]
        $archivePath = @("$archiveFilePath")

        $currentDirectoryInfo = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $expandArchiveResult["Destination"]

        if($currentDirectoryInfo.Exists -eq $true)
        {
            $creationTime = $currentDirectoryInfo.CreationTime
            $attributes = $currentDirectoryInfo.Attributes.ToString()
            $mode = $currentDirectoryInfo.Mode

            $filePaths = dir $expandArchiveResult["Destination"] -Recurse
            foreach($currenFilePath in $filePaths)
            {
                if([System.IO.File]::Exists($currenFilePath.FullName)  -eq $true)
                {
                        $currentFileInfo = New-Object -TypeName System.IO.FileInfo -ArgumentList $currenFilePath
                        $size += $currenFilePath.Length
                }
            }
        }

        $getTargetResourceResult = @{
                                Path = $archivePath; 
                                Destination = $expandArchiveResult["Destination"];
                                CompressionLevel = $CompressionLevel;
                                DestinationType = $DestinationType;
                                MatchSource = $MatchSource;
                                CreationTime = $creationTime;
                                Attributes = $attributes;
                                Size = $size;
                                Mode = $mode;
                            }
   }

   return $getTargetResourceResult
}

<#
.SYNOPSIS 
The Compress-xArchive cmdlet can be used to zip/compress one or more files/directories.
#>
function Compress-xArchive
{
    [CmdletBinding(
    DefaultParameterSetName="Path", 
    SupportsShouldProcess=$true)]
    param 
    (
        [parameter (
        mandatory=$true, 
        Position=0,
        ParameterSetName="Path",
        ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        [parameter (
        mandatory=$true, 
        ParameterSetName="LiteralPath",         
        ValueFromPipeline=$false, 
        ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        [parameter (mandatory=$true,
        Position=1, 
        ValueFromPipeline=$false, 
        ValueFromPipelineByPropertyName=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationPath,

        [parameter (
        mandatory=$false, 
        ValueFromPipeline=$false, 
        ValueFromPipelineByPropertyName=$false)]
        [ValidateSet("Optimal","NoCompression","Fastest")]
        [string]
        $CompressionLevel = "Optimal",

        [parameter (
        mandatory=$false,
        ValueFromPipeline=$false, 
        ValueFromPipelineByPropertyName=$false)]
        [switch]
        $Update = $false 
    )

    # Validate Source Path depeding on Path or LiteralPath parameter set is used.
    # The specied source path conatins one or more files or directories that needs
    # to be compressed.
    switch($PsCmdlet.ParameterSetName)
    {
        "Path"
        {
            IsValidFileSystemPath $Path | Out-Null
            ValidateDuplicateFileSystemPath $PsCmdlet.ParameterSetName $Path
            $sourcePath = $Path;
        }
        "LiteralPath" 
        { 
            IsValidFileSystemPath $LiteralPath | Out-Null
            ValidateDuplicateFileSystemPath $PsCmdlet.ParameterSetName $LiteralPath
            $sourcePath = $LiteralPath;
        }
    }

    $zipFileExtension = ".zip"
    $extension = [system.IO.Path]::GetExtension($DestinationPath)

    # If user does not specify .Zip extension, we append it.
    If($extension -eq [string]::Empty)
    {
        $DestinationPath = $DestinationPath + $zipFileExtension
    }
    else
    {
        $comparisonResult = [string]::Compare($extension, $zipFileExtension, [System.StringComparison]::OrdinalIgnoreCase)

        # Invalid file extension is specifed for the zip file to be created.
        if($comparisonResult -ne 0)
        {
            $errorId = "NotSupportedArchiveFileExtension"; 
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument;
            $errorMessage = $($LocalizedData.InvalidZipFileExtensionError) -f @($extension, $zipFileExtension)
            $exception = New-Object System.IO.IOException $errorMessage ;
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
            $PSCmdlet.ThrowTerminatingError($errorRecord);
        }
    }

    $destinationParentDir = [system.IO.Path]::GetDirectoryName($DestinationPath)

    IsValidFileSystemPath $destinationParentDir | Out-Null


    if([System.IO.File]::Exists($DestinationPath) -and $Update -eq $false)
    {
        $errorId = "ArchiveFileExists"; 
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument;
        $errorMessage = $($LocalizedData.ZipFileExistError) -f @($extension, $zipFileExtension)
        $exception = New-Object System.IO.IOException $errorMessage ;
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
        $PSCmdlet.ThrowTerminatingError($errorRecord);
    }

    CompressArchiveHelper $sourcePath $DestinationPath $CompressionLevel $Update
}

function IsValidFileSystemPath 
{
    param 
    (
        [string[]] $path
    )
    
    $result = $false;

    # null and empty check are are already done on Path parameter at the cmdlet layer.
    foreach($currentPath in $path)
    {
        try
        {
            if([System.IO.File]::Exists($currentPath) -or [System.IO.Directory]::Exists($currentPath))
            {
                $result = $true
            }
            else
            {
                $errorId = "PathNotFound"; 
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument;
                $errorMessage = $($LocalizedData.PathNotFoundError) -f @($currentPath)
                $exception = New-Object System.IO.IOException $errorMessage ;
                $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
                $PSCmdlet.ThrowTerminatingError($errorRecord);
            }
        }
        catch
        {
            throw $_
        }
    }

    return $result;
}

function ValidateDuplicateFileSystemPath 
{
    param 
    (
        [string] $inputParameter,
        [string[]] $path
    )
    
    $uniqueInputPaths = @()

    # null and empty check are are already done on Path parameter at the cmdlet layer.
    foreach($currentPath in $path)
    {
        $currentInputPath = $currentPath.ToUpper()
        if($uniqueInputPaths.Contains($currentInputPath))
        {
            $errorId = "DuplicatePathFound"; 
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument;
            $errorMessage = $($LocalizedData.DuplicatePathFoundError) -f @($inputParameter, $currentPath, $inputParameter)
            $exception = New-Object System.IO.IOException $errorMessage ;
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
            $PSCmdlet.ThrowTerminatingError($errorRecord);
        }
        else
        {
            $uniqueInputPaths += $currentInputPath
        }
    }
}

function CompressionLevelMapper
{
    param 
    (
        [string] $compressionLevel
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression

    $compressionLevelFormat = [System.IO.Compression.CompressionLevel]::Optimal

    # CompressionLevel format is already validated at the cmdlet layer.
    switch($compressionLevel.ToString())
    {
        "Fastest"
        {
            $compressionLevelFormat = [System.IO.Compression.CompressionLevel]::Fastest
        }
        "NoCompression" 
        { 
            $compressionLevelFormat = [System.IO.Compression.CompressionLevel]::NoCompression
        }
    }

    return $compressionLevelFormat
}

function CompressArchiveHelper 
{
    param 
    (
        [string[]] $sourcePath,
        [string]   $destinationPath,
        [string]   $compressionLevel,
        [bool]     $isUpdateMode
    )

    $sourceFilePaths = @()
    $sourceDirPaths = @()

    foreach($currentPath in $sourcePath)
    {
        if([System.IO.File]::Exists($currentPath))
        {
            $sourceFilePaths += $currentPath
        }
        else
        {
            $sourceDirPaths += $currentPath
        }
    }

    # The Soure Path contains one or more directory (this directory can have files under it) and no files to be compressed.
    if($sourceFilePaths.Count -eq 0 -and $sourceDirPaths.Count -gt 0)
    {
        foreach($currentSourceDirPath in $sourceDirPaths)
        {
            CompressSingleDirHelper $currentSourceDirPath $destinationPath $compressionLevel $true $isUpdateMode
        }
    }

    # The Soure Path contains only files to be compressed.
    elseIf($sourceFilePaths.Count -gt 0 -and $sourceDirPaths.Count -eq 0)
    {
        CompressFilesHelper $sourceFilePaths $destinationPath $compressionLevel $isUpdateMode
    }
    # The Soure Path contains one or more files and one or more directories (this directory can have files under it) to be compressed.
    elseif($sourceFilePaths.Count -gt 0 -and $sourceDirPaths.Count -gt 0)
    {
        foreach($currentSourceDirPath in $sourceDirPaths)
        {
            CompressSingleDirHelper $currentSourceDirPath $destinationPath $compressionLevel $true $isUpdateMode
        }

        CompressFilesHelper $sourceFilePaths $destinationPath $compressionLevel $isUpdateMode
    }
}

function CompressFilesHelper 
{
    param 
    (
        [string[]] $sourceFilePaths,
        [string]   $destinationPath,
        [string]   $compressionLevel,
        [bool]     $isUpdateMode
    )

    ZipArchiveHelper $sourceFilePaths $destinationPath $compressionLevel $isUpdateMode $null
}

function CompressSingleDirHelper 
{
    param 
    (
        [string] $sourceDirPath,
        [string] $destinationPath,
        [string] $compressionLevel,
        [bool]   $useParentDirAsRoot,
        [bool]   $isUpdateMode
    )

    $subDirFiles = @()

    if($useParentDirAsRoot)
    {
        $sourceDirInfo = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $sourceDirPath
        $sourceDirFullName = $sourceDirInfo.Parent.FullName

        # If the directory is present at the drive level the DirectoryInfo.Parent include '\' example: C:\
        # On the other hand if the directory exists at a deper level then DirectoryInfo.Parent 
        # has just the path (without an ending '\'). example C:\source 
        if($sourceDirFullName.Length -eq 3)
        {
            $modifiedSourceDirFullName = $sourceDirFullName
        }
        else
        {
            $modifiedSourceDirFullName = $sourceDirFullName + "\"
        }
    }
    else
    {
        $sourceDirFullName = $sourceDirPath
        $modifiedSourceDirFullName = $sourceDirFullName + "\"
    }

    $dirContents = dir $sourceDirPath -Recurse
    foreach($currentContent in $dirContents)
    {
        if([System.IO.File]::Exists($currentContent.FullName))
        {
            $subDirFiles += $currentContent.FullName
        }
        else
        {
            # The currentContent points to a directory.
            # We need to check if the directory is an empty directory, if so such a
            # directory has to be explictly added to the archive file.
            # if there are no files in the directory the GetFiles() API returns an empty array.
            $files = $currentContent.GetFiles()
            if($files.Count -eq 0)
            {
                $subDirFiles += $currentContent.FullName + "\"
            }
        }
    }

    $sourcePaths = $subDirFiles

    ZipArchiveHelper $sourcePaths $destinationPath $compressionLevel $isUpdateMode $modifiedSourceDirFullName
}

function ZipArchiveHelper 
{
    param 
    (
        [string[]] $sourcePaths,
        [string]   $destinationPath,
        [string]   $compressionLevel,
        [bool]     $isUpdateMode,
        [string]   $modifiedSourceDirFullName
    )

    $fileMode = [System.IO.FileMode]::Create
    if([System.IO.File]::Exists($DestinationPath))
    {
        $fileMode = [System.IO.FileMode]::Open
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression

    try
    {
        $archiveFileStreamArgs = @($destinationPath, $fileMode)
        $archiveFileStream = New-Object -TypeName System.IO.FileStream -ArgumentList $archiveFileStreamArgs

        $zipArchiveArgs = @($archiveFileStream, [System.IO.Compression.ZipArchiveMode]::Update, $false)
        $zipArchive = New-Object -TypeName System.IO.Compression.ZipArchive -ArgumentList $zipArchiveArgs

        foreach($currentFilePath in $sourcePaths)
        {
            if($modifiedSourceDirFullName -ne $null -and $modifiedSourceDirFullName.Length -gt 0)
            {
                $index = $currentFilePath.IndexOf($modifiedSourceDirFullName, [System.StringComparison]::OrdinalIgnoreCase)
                $currentFilePathSubString = $currentFilePath.Substring($index, $modifiedSourceDirFullName.Length)
                $relativeFilePath = $currentFilePath.Replace($currentFilePathSubString, "").Trim()
            }
            else
            {
                $relativeFilePath = [System.IO.Path]::GetFileName($currentFilePath)
            }

            # Update mode is selected.
            # Check to see if archive file already contains one or more zip files in it.
            if($isUpdateMode -eq $true -and $zipArchive.Entries.Count -gt 0)
            {                    
                $entryToBeUpdated = $null

                # Check if the file already exists in the archive file. 
                # If so replace it with new file from the input source.
                # If the file does not exist in the archive file then default to 
                # create mode and create the entry in the archive file.

                foreach($currentArchiveEntry in $zipArchive.Entries)
                {
                    $comparisonResult = [string]::Compare($currentArchiveEntry.FullName, $relativeFilePath, [System.StringComparison]::OrdinalIgnoreCase)

                    if($comparisonResult -eq 0)
                    {
                        $entryToBeUpdated = $currentArchiveEntry
                            
                        break
                    }
                }

                if($entryToBeUpdated -ne $null)
                {
                    $entryToBeUpdated.Delete()
                }
            }

            $compression = CompressionLevelMapper $compressionLevel
            if($relativeFilePath[$relativeFilePath.Length -1] -ne '\')
            {
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $currentFilePath, $relativeFilePath, $compression)
            }
            else
            {
                $currentArchiveEntry = $zipArchive.CreateEntry("$relativeFilePath", $compression)
            }
        }
    }
    finally
    {
        If($null -ne $zipArchive)
        {
            $zipArchive.Dispose()
        }

        If($null -ne $archiveFileStream)
        {
            $archiveFileStream.Dispose()
        }
    }
}

function ValidateExpandParameters 
{
    param 
    (
        [string[]] $path,
        [string]   $destination,
        [string]   $destinationType
    )

   if($destinationType -eq "Directory")
   {
        # Source - [-Path]: Specifies the path to archive file
        # Destination - [-Destination]: Specifies the path to directory where archive file contents would be expanded.
        if($path.Count -gt 1)
        {
            $errorId = "InvalidArguement"; 
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument;
            $errorMessage = $($LocalizedData.InvalidPathForExpandError) -f @($path)
            $exception = New-Object System.IO.IOException $errorMessage ;
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
            $PSCmdlet.ThrowTerminatingError($errorRecord);
        }
        
        # When DestinationType is Directory, The source needs to be a zip file & Destination needs to be a directory
        $zipFileExtension = ".zip"
        $extension = [system.IO.Path]::GetExtension($path[0])

        if($extension -ne $zipFileExtension)
        {
            $errorId = "NotSupportedArchiveFileExtension"; 
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument;
            $errorMessage = $($LocalizedData.InvalidZipFileExtensionError) -f @($extension, $zipFileExtension)
            $exception = New-Object System.IO.IOException $errorMessage ;
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
            $PSCmdlet.ThrowTerminatingError($errorRecord);
        }
   }
}

function ValidateCompressParameters 
{
    param 
    (
        [string[]] $path,
        [string]   $destination,
        [string]   $destinationType
    )

   if($destinationType -eq "File")
   {
        $zipFileExtension = ".zip"
        # When DestinationType is File, The Destination needs to be a file with .zip extension.
        $result = Test-Path $destination -Type Container
        if($result -eq $true)
        {
            $errorId = "InvalidArguement"; 
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument;
            $errorMessage = $($LocalizedData.InvalidDirZipFileExtensionError) -f @($destination, $zipFileExtension)
            $exception = New-Object System.IO.IOException $errorMessage ;
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
            $PSCmdlet.ThrowTerminatingError($errorRecord);
        }

        $extension = [system.IO.Path]::GetExtension($destination)
        if($extension -ne $zipFileExtension)
        {
            $errorId = "NotSupportedArchiveFileExtension"; 
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument;
            $errorMessage = $($LocalizedData.InvalidZipFileExtensionError) -f @($extension, $zipFileExtension)
            $exception = New-Object System.IO.IOException $errorMessage ;
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
            $PSCmdlet.ThrowTerminatingError($errorRecord);
        }
   }
}

function CreateArchiveCache
{
    param 
    (
        [string]   $archiveFile,
        [string[]] $path,
        [string]   $compressionLevel
    )

    $zipFileInfo = New-Object -TypeName System.IO.FileInfo -ArgumentList $archiveFile

    $archiveCacheFileName = $zipFileInfo.FullName.GetHashCode().ToString()
    $archiveCacheFileFullName = [System.IO.Path]::Combine($compressCacheLocation, $archiveCacheFileName + ".xml")

    if(-not (Test-Path $compressCacheLocation))
    {
        New-Item $compressCacheLocation -Type Directory | Out-Null
    }

    $archiveTimeStampCache = @{}
    $archiveTimeStampCache.Add($zipFileInfo.FullName, $zipFileInfo.LastWriteTimeUtc.ToString())

    # Adding CompressionLevel to the archive file specific Cache. 
    $archiveTimeStampCache.Add($CompressionLevelString, $compressionLevel)

    # Get the list of all files (including the ones present in the subdirectories).
    $sourceFilePaths = @()
    foreach($currentPath in $path)
    {
        if([System.IO.File]::Exists($currentPath))
        {
            $sourceFilePaths += $currentPath
        }
        else
        {
            $currentDirPaths = dir $currentPath -Recurse
            foreach($itemPath in $currentDirPaths)
            {
                if([System.IO.File]::Exists($itemPath.FullName))
                {
                    $sourceFilePaths += $itemPath.FullName
                }
                else
                {
                    # The currentContent points to a directory.
                    # We need to check if the directory is an empty directory, if so such a
                    # directory has to be explictly added to the archive file.
                    # if there are no files in the directory the GetFiles() API returns an empty array.
                    $files = $itemPath.GetFiles()
                    if($files.Count -eq 0)
                    {
                        $sourceFilePaths += $itemPath.FullName
                    }
                }
            }
        }
    }

    foreach($currentPath in $sourceFilePaths)
    {
        if([System.IO.File]::Exists($currentPath))
        {
            $currentItemInfo = New-Object -TypeName System.IO.FileInfo -ArgumentList $currentPath
            $itemCountString = $FileCountString
        }
        else
        {
            $currentItemInfo = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $currentPath
            $itemCountString = $DirectoryCountString
        }

        if($archiveTimeStampCache.ContainsKey($currentItemInfo.FullName))
        {
            $currentCacheItem = $archiveTimeStampCache[$currentItemInfo.FullName]
            $currentCacheItem[$itemCountString] += 1
        }
        else
        {
            $itemCache = @{}
            $itemCache.Add($LastWriteTimeUtcString, $currentItemInfo.LastWriteTimeUtc.ToString())
            $itemCache.Add($itemCountString, 1)
            $archiveTimeStampCache.Add($currentItemInfo.FullName, $itemCache)
        }
    }

    Export-CliXml -Path $archiveCacheFileFullName -InputObject $archiveTimeStampCache
}

function DeleteArchiveFileAndItsCache
{
    param 
    (
        [string] $archiveFile
    )

    $zipFileInfo = New-Object -TypeName System.IO.FileInfo -ArgumentList $archiveFile

    $archiveCacheFileName = $zipFileInfo.FullName.GetHashCode().ToString()
    $archiveCacheFileFullName = [System.IO.Path]::Combine($compressCacheLocation, $archiveCacheFileName + ".xml")

    if([System.IO.File]::Exists($archiveCacheFileFullName))
    {
        del "$archiveCacheFileFullName" -Force -Recurse -ErrorAction SilentlyContinue
    }

    if([System.IO.File]::Exists($archiveFile))
    {
        del "$archiveFile" -Force -Recurse -ErrorAction SilentlyContinue
    }
}

function IsArchiveCacheUpdated
{
    param 
    (
        [string]   $archiveFile,
        [string[]] $path,
        [boolean]  $matchSource,
        [string]   $compressionLevel
    )

    Write-Debug "MatchSource is set to  $matchSource"

    $result = $false

    $zipFileInfo = New-Object -TypeName System.IO.FileInfo -ArgumentList $archiveFile

    $archiveCacheFileName = $zipFileInfo.FullName.GetHashCode().ToString()

    $archiveCacheFileFullName = [System.IO.Path]::Combine($compressCacheLocation, $archiveCacheFileName + ".xml")

    if([System.IO.File]::Exists($archiveCacheFileFullName))
    {
        $archiveTimeStampCache = Import-Clixml -Path $archiveCacheFileFullName
        if($archiveTimeStampCache -ne $null)
        {
            if($archiveTimeStampCache.ContainsKey($zipFileInfo.FullName))
            {
                # Validate to make sure that the LastWriteTimeUtc in cache matchs that of the archive file.
                $archiveFileInCacheLastWriteTimeUtc = $archiveTimeStampCache[$zipFileInfo.FullName]
                $archiveFileLastWriteTimeUtc = $zipFileInfo.LastWriteTimeUtc.ToString()
                $comparisonResult = [string]::Compare($archiveFileInCacheLastWriteTimeUtc, $archiveFileLastWriteTimeUtc, [System.StringComparison]::OrdinalIgnoreCase)
                if($comparisonResult -ne 0)
                {
                    return $result
                }

                # Validate to make sure that the CompressionLevel in cache matchs with the specifed on in method signature.
                $CompressionLevelInCache = $archiveTimeStampCache[$CompressionLevelString]
                $comparisonResult = [string]::Compare($CompressionLevelInCache, $compressionLevel, [System.StringComparison]::OrdinalIgnoreCase)
                if($comparisonResult -ne 0)
                {
                    return $result
                }
            
                if($matchSource -eq $true)
                {
                    if([System.IO.File]::Exists($archiveFile))
                    {
                        Add-Type -AssemblyName System.IO.Compression.FileSystem
                        Add-Type -AssemblyName System.IO.Compression

                        try
                        {
                            $archiveFileStreamArgs = @($archiveFile, [System.IO.FileMode]::Open)
                            $archiveFileStream = New-Object -TypeName System.IO.FileStream -ArgumentList $archiveFileStreamArgs
                            $zipArchiveArgs = @($archiveFileStream, [System.IO.Compression.ZipArchiveMode]::Read, $false)
                            $zipArchive = New-Object -TypeName System.IO.Compression.ZipArchive -ArgumentList $zipArchiveArgs
                            $fileCountFromInspectiveArchive = $zipArchive.Entries.Count
                        }
                        finally
                        {
                            If($null -ne $zipArchive)
                            {
                                $zipArchive.Dispose()
                            }

                            If($null -ne $archiveFileStream)
                            {
                                $archiveFileStream.Dispose()
                            }
                        }
                    }
                    else
                    {
                        return $result
                    }


                    # Validate all the paths specified in the configuration to ensure that they are valida file system paths.
                    IsValidFileSystemPath $path | Out-Null

                    # Get the list of all files with out duplicates (including the ones present in the subdirectories).
                    # We need to filter out the duplicate paths to the same file (i.e., duplicate path to the same file supplied through user input).
                    $sourceFilePaths = @()
                    foreach($currentPath in $path)
                    {
                        if([System.IO.File]::Exists($currentPath))
                        {
                            if($sourceFilePaths.Contains($currentPath) -eq $false)
                            {
                                $sourceFilePaths += $currentPath
                            }
                        }
                        else
                        {
                            $currentDirPaths = dir $currentPath -Recurse
                            foreach($itemPath in $currentDirPaths)
                            {
                                if([System.IO.File]::Exists($itemPath.FullName))
                                {
                                    if($sourceFilePaths.Contains($itemPath.FullName) -eq $false)
                                    {
                                        $sourceFilePaths += $itemPath.FullName
                                    }
                                }
                                else
                                {
                                    # The currentContent points to a directory.
                                    # We need to check if the directory is an empty directory, if so such a
                                    # directory has to be explictly added to the archive file.
                                    # if there are no files in the directory the GetFiles() API returns an empty array.
                                    $files = $itemPath.GetFiles()
                                    if($files.Count -eq 0)
                                    {
                                        if($sourceFilePaths.Contains($itemPath.FullName) -eq $false)
                                        {
                                            $sourceFilePaths += $itemPath.FullName
                                        }
                                    }
                                }
                            }
                        }
                    }

                    $fileCount = 0
                    foreach($currentFilePath in $sourceFilePaths)
                    {
                        if([System.IO.File]::Exists($currentFilePath))
                        {
                            $currentInfo = New-Object -TypeName System.IO.FileInfo -ArgumentList $currentFilePath
                            $itemCountString = $FileCountString
                        }
                        else
                        {
                            $currentInfo = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $currentFilePath
                            $itemCountString = $DirectoryCountString
                        }

                        if($archiveTimeStampCache.ContainsKey($currentInfo.FullName))
                        {
                            $currentFileFullName = $currentInfo.FullName
                            Write-Debug "Cache has an entry for $currentFileFullName"

                            $currentCacheItem = $archiveTimeStampCache[$currentInfo.FullName]
                            $fileCount += $currentCacheItem[$itemCountString]
                            $currentItemInCacheLastWriteTimeUtc = $currentCacheItem[$LastWriteTimeUtcString]

                            $currentItemLastWriteTimeUtc =  $currentInfo.LastWriteTimeUtc.ToString()
                            $comparisonResult = [string]::Compare($currentItemInCacheLastWriteTimeUtc, $currentItemLastWriteTimeUtc, [System.StringComparison]::OrdinalIgnoreCase)
                            if($comparisonResult -ne 0)
                            { 
                                Write-Debug "The last updated timestamp of the $currentInfo in Cache is  $currentItemInCacheLastWriteTimeUtc where as the actual last updated timestamp is $currentItemLastWriteTimeUtc"
                                return $result
                            }
                        }
                        else
                        {
                            Write-Debug "The Cache does not have an entry for the $currentFilePath"

                            # The Cache does not contain the new Path specified. Hence new files have been added to the source.
                            return $result
                        }
                        
                    }

                    if($fileCountFromInspectiveArchive -ne $fileCount)
                    {
                        return $result
                    }

                    $result = $true
                }
                else
                {
                    $result = $true
                }
            }
        }
     }

    return $result
}

Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource
