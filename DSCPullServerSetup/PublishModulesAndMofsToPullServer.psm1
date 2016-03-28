<#
.Synopsis
   Package DSC modules and mof configuration document and publish them on an enterprise DSC pull server in the required format.
.DESCRIPTION
   Uses Publish-DSCModulesAndMof function to package DSC modules into zip files with the version info. 
   Publishes the zip modules on "$env:ProgramFiles\WindowsPowerShell\DscService\Modules".
   Publishes all mof configuration documents that are present in the $Source folder on "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"-
   Use $Force to overwrite the version of the module that exists in the PowerShell module path with the version from the $source folder.
   Use $ModuleNameList to specify the names of the modules to be published if the modules do not exist in $Source folder.
.EXAMPLE
    $ModuleList = @("xWebAdministration", "xPhp")
    Publish-DSCModuleAndMof -Source C:\LocalDepot -ModuleNameList $ModuleList
.EXAMPLE
    Publish-DSCModuleAndMof -Source C:\LocalDepot -Force

#>

# Tools to use to package DSC modules and mof configuration document and publish them on enterprise DSC pull server in the required format
function Publish-DSCModuleAndMof
{
    [CmdletBinding()]
    param(
    # The folder that contains the configuration mof documents and modules to be published on Pull server. 
    # Everything in this folder will be packaged and published.
    [Parameter(Mandatory=$True)]
    [string]$Source = $pwd,
     
    # Switch to overwrite the module in PSModulePath with the version provided in $Sources.
    [switch]$Force, 

    # Package and publish the modules listed in $ModuleNameList based on PowerShell module path content.
    [string[]]$ModuleNameList
    )

    # Create working directory
    $tempFolder = "$pwd\temp"
    New-Item -Path $tempFolder -ItemType Directory -Force -ErrorAction SilentlyContinue

    # Copy the mof documents from the $Source to working dir
    Copy-Item -Path "$Source\*.mof" -Destination $tempFolder -Force -Verbose

    # Start Deployment!
    Log -Scope $MyInvocation -Message 'Start Deployment'
    CreateZipFromPSModulePath -ListModuleNames $ModuleNameList -Destination $tempFolder
    CreateZipFromSource -Source $Source -Destination $tempFolder
    # Generate the checkSum file for all the zip and mof files.
    New-DSCCheckSum -Path $tempFolder -Force
    # Publish mof and modules to pull server repositories
    PublishModulesAndChecksum -Source $tempFolder
    PublishMofDocuments -Source $tempFolder
    # Deployment is complete!
    Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
    Log -Scope $MyInvocation -Message 'End Deployment'

}

#Package the modules using powershell module path
function CreateZipFromPSModulePath
{
    param($ListModuleNames, $Destination)

    # Move all required  modules from powershell module path to a temp folder and package them
    if ([string]::IsNullOrEmpty($ListModuleNames))
    {
        Log -Scope $MyInvocation -Message "No additional modules are specified to be packaged." 
    }
    
    foreach ($module in $ListModuleNames)
    {
        $allVersions = Get-Module -Name $module -ListAvailable -Verbose        
        # Package all versions of the module
        foreach ($moduleVersion in $allVersions)
        {
            $name   = $moduleVersion.Name
            $source = "$Destination\$name"
            # Create package zip
            $path    = $moduleVersion.ModuleBase
            $version = $moduleVersion.Version.ToString()
            Log -Scope $MyInvocation -Message "Zipping $name ($version)"
            Compress-Archive -Path "$path\*" -DestinationPath "$source.zip" -Verbose -Force 
            $newName = "$Destination\$name" + "_" + "$version" + ".zip"
            # Rename the module folder to contain the version info.
            if (Test-Path $newName)
            {
                Remove-Item $newName -Recurse -Force 
            }
            Rename-Item -Path "$source.zip" -NewName $newName -Force    
        } 
    }   

}

# Function to package modules using a given folder after installing to psmodule path.
function CreateZipFromSource
{
    param($Source, $Destination)
    # for each module under $Source folder create a zip package that has the same name as the folder. 
    $allModulesInSource = Get-ChildItem -Path $Source -Directory
    $modules = @()
   
    foreach ($item in $allModulesInSource)
    {
        $name = $Item.Name
        $alreadyExists = Get-Module -Name $name -ListAvailable -Verbose
        if (($alreadyExists -eq $null) -or ($Force))
        {
            # Install the modules into PowerShell module path and overwrite the content 
            Copy-Item -Path $item.FullName -Recurse -Force -Destination "$env:ProgramFiles\WindowsPowerShell\Modules" -Verbose            
        }              
        else
        {
            Write-Warning "Skipping module overwrite. Module with the name $name already exists."
            Write-Warning "Please specify -Force to overwrite the module with the local version of the module located in $Source or list names of the modules in ModuleNameList parameter to be packaged from PowerShell module pat instead and remove them from $Source folder"
        }
        $modules += @("$name")
    }
    # Package the module in $destination
    CreateZipFromPSModulePath -ListModuleNames $modules -Destination $Destination
}


# Deploy modules to the Pull sever repository.
function PublishModulesAndChecksum
{
    param($Source)
    # Check if the current machine is a server sku.
    $moduleRepository = "$env:ProgramFiles\WindowsPowerShell\DscService\Modules"
    if ((Get-Module ServerManager -ListAvailable) -and (Test-Path $moduleRepository))
    {
        Log -Scope $MyInvocation -Message "Copying modules and checksums to [$moduleRepository]."
        Copy-Item -Path "$Source\*.zip*" -Destination $moduleRepository -Force -Verbose
    }
    else
    {
        Write-Warning "Copying modules to Pull server module repository skipped because the machine is not a server sku or Pull server endpoint is not deployed."
    }   
    
}

# function deploy configuration and their checksums.
function PublishMofDocuments
{
   param($Source)
    # Check if the current machine is a server sku.
    $mofRepository = "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"
    if ((Get-Module ServerManager -ListAvailable) -and (Test-Path $mofRepository))    
    {
        Log -Scope $MyInvocation -Message "Copying mofs and checksums to [$mofRepository]."
        Copy-Item -Path "$Source\*.mof*" -Destination $mofRepository -Force -Verbose
    }
    else
    {
        Write-Warning "Copying configuration(s) to Pull server configuration repository skipped because the machine is not a server sku or Pull server endpoint is not deployed."
    } 
}

Function Log
{
    Param(
        $Date = $(Get-Date),
        $Scope, 
        $Message
    )

    Write-Verbose "$Date [$($Scope.MyCommand)] :: $Message"
}

Export-ModuleMember -Function Publish-DSCModuleAndMof
