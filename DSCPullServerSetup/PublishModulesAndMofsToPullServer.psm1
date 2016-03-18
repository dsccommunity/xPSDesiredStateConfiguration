<#
.Synopsis
   Package DSC modules and mof configuration document and publish them on enterprise DSC pull server in the required format
.DESCRIPTION
   Uses Publish-DSCModulesAndMofs cmdlet to package DSC modules into zip files with the version info. If 
   Publishes the zip modules on "$env:ProgramFiles\WindowsPowerShell\DscService\Modules"
   Publishes all mof configuration documents that present in $Source folder on "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"
   Use $Force to overwrite the version of the module that exists in powershell module path with the version from $source folder
   Use $ModuleNameList to specify the names of the modules to be published if the modules do not exist in $Source folder
   
.EXAMPLE
    $moduleList = @("xWebAdministration", "xPhp")
    Publish-DSCModuleAndMof -Source C:\LocalDepot -ModuleNameList $moduleList
.EXAMPLE
    Publish-DSCModuleAndMof -Source C:\LocalDepot -Force

#>

# Tools to use to package DSC modules and mof configuration document and publish them on enterprise DSC pull server in the required format

function Publish-DSCModuleAndMof
{
param(

[Parameter(Mandatory=$True)]
[string]$Source = $pwd, # The folder that contains the configuration mof documents and modules to be published on pull server. Everything in this folder will be packaged and published.
[switch]$Force, #switch to overwrite the module in PSModulePath with the version provided in $Sources
[string[]]$ModuleNameList # Package and publish the modules listed in $ModuleNameList based on powershell module path content

)

#Create a working directory
$tempFolder = "$pwd\temp"
New-Item -Path $tempFolder -ItemType Directory -Force -ErrorAction SilentlyContinue

#Copy the mof documents from the $Source to working dir
Copy-Item -Path "$Source\*.mof" -Destination $tempFolder -Force -Verbose

#Start Deployment!
Write-Host "Start deployment"
CreateZipFromPSModulePath -listModuleNames $ModuleNameList -destination $tempFolder
CreateZipFromSource -source $Source -destination $tempFolder
# Generate the checkSum file for all the zip and mof files.
New-DSCCheckSum $tempFolder -Force
# Publish mof and modules to pull server repositories
PublishModulesAndChecksum -source $tempFolder
PublishMofDocuments -source $tempFolder
#Deployment is complete!
Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "End deployment"

}

#Package the modules using powershell module path
function CreateZipFromPSModulePath
{
   param($listModuleNames, $destination)
    # Move all required  modules from powershell module path to a temp folder and package them
    if(($listModuleNames -eq $null) -or ($listModuleNames.Count -eq 0))
    {
        Write-Host "No additional modules are specified to be packaged."
    }
    foreach ($module in $listModuleNames)
    {
        $allVersions = Get-Module -Name $module -ListAvailable -Verbose        
        #package all versions of the module
        foreach($moduleVersion in $allVersions)
        {
            $name = $moduleVersion.Name
            $source = "$destination\$name"
            #Create package zip
            $path  = $moduleVersion.ModuleBase
            Compress-Archive -Path "$path\*" -DestinationPath "$source.zip" -Verbose -Force 
            $version = $moduleVersion.Version.ToString()
            $newName = "$destination\$name" + "_" + "$version" + ".zip"
            # Rename the module folder to contain the version info.
            if(Test-Path($newName))
            {
                Remove-Item $newName -Recurse -Force 
            }
            Rename-Item -Path "$source.zip" -NewName $newName -Force
            
          } 
    }   

}
#Function to package modules using a given folder after installing to ps module path.
function CreateZipFromSource
{
   param($source, $destination)
   # for each module under $Source folder create a zip package that has the same name as the folder. 
    $allModulesInSource = Get-ChildItem $source -Directory
    $modules = @()
   
    foreach ($item in $allModulesInSource)
    {
        $name = $item.Name
        $alreadyExists = Get-Module -Name $name -ListAvailable -Verbose
        if(($alreadyExists -eq $null) -or ($Force))
        {
            #install the modules into powershell module path and overwrite the content 
            Copy-Item $item.FullName -Recurse -Force -Destination "$env:ProgramFiles\WindowsPowerShell\Modules" -Verbose            
        }              
        else
        {
            Write-Host "Skipping module overwrite. Module with the name $name already exists. Please specify -Force to overwrite the module with the local version of the module located in $source or list names of the modules in ModuleNameList parameter to be packaged from powershell module pat instead and remove them from $source folder" -Fore Red
        }
        $modules+= @("$name")
    }
    #Package the module in $destination
    CreateZipFromPSModulePath -listModuleNames $modules -destination $destination
}


# Deploy modules to the pullsever repository.
function PublishModulesAndChecksum
{
    param($source)
    # Check if the current machine is a server sku.
    $moduleRepository = "$env:ProgramFiles\WindowsPowerShell\DscService\Modules"
    if( (Get-Module ServerManager -ListAvailable) -and (Test-Path ($moduleRepository)))
    {
        Copy "$source\*.zip*" $moduleRepository -Force -Verbose
    }
    else
    {
        Write-Host "Copying modules to pullserver module repository skipped because the machine is not a server sku or Pull server endpoint is not deployed." -Fore Yellow
    }   
    
}

# function deploy configuratoin and thier checksum.
function PublishMofDocuments
{
   param($source)
    # Check if the current machine is a server sku.
    $mofRepository = "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"
    if( (Get-Module ServerManager -ListAvailable) -and (Test-Path ($mofRepository)) )    
    {
        Copy-Item "$source\*.mof*" $mofRepository -Force -Verbose
    }
    else
    {
        Write-Host "Copying configuration(s) to pullserver configuration repository skipped because the machine is not a server sku or Pull server endpoint is not deployed." -Fore Yellow
    } 
}
Export-ModuleMember -Function Publish-DSCModuleAndMof
