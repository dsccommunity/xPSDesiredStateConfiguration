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
    $TempFolder = "$pwd\temp"
    New-Item -Path $TempFolder -ItemType Directory -Force -ErrorAction SilentlyContinue

    # Copy the mof documents from the $Source to working dir
    Copy-Item -Path "$Source\*.mof" -Destination $TempFolder -Force -Verbose

    # Start Deployment!
    Log -Scope $MyInvocation -Message 'Start Deployment'
    CreateZipFromPSModulePath -ListModuleNames $ModuleNameList -Destination $TempFolder
    CreateZipFromSource -Source $Source -Destination $TempFolder
    # Generate the checkSum file for all the zip and mof files.
    New-DSCCheckSum -Path $TempFolder -Force
    # Publish mof and modules to pull server repositories
    PublishModulesAndChecksum -Source $TempFolder
    PublishMofDocuments -Source $TempFolder
    # Deployment is complete!
    Remove-Item -Path $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
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
    
    foreach ($Module in $ListModuleNames)
    {
        $AllVersions = Get-Module -Name $Module -ListAvailable -Verbose        
        # Package all versions of the module
        foreach ($ModuleVersion in $AllVersions)
        {
            $Name   = $ModuleVersion.Name
            $Source = "$Destination\$Name"
            # Create package zip
            $Path    = $ModuleVersion.ModuleBase
            $Version = $ModuleVersion.Version.ToString()
            Log -Scope $MyInvocation -Message "Zipping $Name ($Version)"
            Compress-Archive -Path "$Path\*" -DestinationPath "$Source.zip" -Verbose -Force 
            $NewName = "$Destination\$Name" + "_" + "$Version" + ".zip"
            # Rename the module folder to contain the version info.
            if (Test-Path $NewName)
            {
                Remove-Item $NewName -Recurse -Force 
            }
            Rename-Item -Path "$source.zip" -NewName $NewName -Force    
        } 
    }   

}

# Function to package modules using a given folder after installing to psmodule path.
function CreateZipFromSource
{
    param($Source, $Destination)
    # for each module under $Source folder create a zip package that has the same name as the folder. 
    $AllModulesInSource = Get-ChildItem -Path $Source -Directory
    $Modules = @()
   
    foreach ($Item in $AllModulesInSource)
    {
        $Name = $Item.Name
        $AlreadyExists = Get-Module -Name $Name -ListAvailable -Verbose
        if (($AlreadyExists -eq $null) -or ($Force))
        {
            # Install the modules into PowerShell module path and overwrite the content 
            Copy-Item -Path $Item.FullName -Recurse -Force -Destination "$env:ProgramFiles\WindowsPowerShell\Modules" -Verbose            
        }              
        else
        {
            Write-Warning "Skipping module overwrite. Module with the name $Name already exists."
            Write-Warning "Please specify -Force to overwrite the module with the local version of the module located in $Source or list names of the modules in ModuleNameList parameter to be packaged from PowerShell module pat instead and remove them from $Source folder"
        }
        $Modules += @("$Name")
    }
    # Package the module in $destination
    CreateZipFromPSModulePath -ListModuleNames $Modules -Destination $Destination
}


# Deploy modules to the Pull sever repository.
function PublishModulesAndChecksum
{
    param($Source)
    # Check if the current machine is a server sku.
    $ModuleRepository = "$env:ProgramFiles\WindowsPowerShell\DscService\Modules"
    if ((Get-Module ServerManager -ListAvailable) -and (Test-Path $ModuleRepository))
    {
        Log -Scope $MyInvocation -Message "Copying modules and checksums to [$ModuleRepository]."
        Copy-Item -Path "$Source\*.zip*" -Destination $ModuleRepository -Force -Verbose
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
    $MofRepository = "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"
    if ((Get-Module ServerManager -ListAvailable) -and (Test-Path $MofRepository))    
    {
        Log -Scope $MyInvocation -Message "Copying mofs and checksums to [$MofRepository]."
        Copy-Item -Path "$Source\*.mof*" -Destination $MofRepository -Force -Verbose
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