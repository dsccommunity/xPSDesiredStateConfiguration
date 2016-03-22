<#
.Synopsis
   Package DSC modules and mof configuration document and publish them on enterprise DSC pull server in the required format
.DESCRIPTION
   Uses Publish-DSCModuleAndMof cmdlet to package DSC modules that present in $Source or in $ModuleNameList into zip files with the version info and publish them with mof configuration documents that present in $Source on Pull server. 
   Publishes the zip modules on "$env:ProgramFiles\WindowsPowerShell\DscService\Modules"
   Publishes all mof configuration documents on "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"
   Use $Force to force packaging the version that exists in $Source folder if a different version of the module exists in powershell module path
   Use $ModuleNameList to specify the names of the modules to be published (all versions if multiple versions of the module are installed) if the modules do not exist in local folder $Source

.EXAMPLE
    Publish-DSCModuleAndMof -Source C:\LocalDepot
       
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
#Function to package modules using a given folder.
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
            $localCopies = Get-Module $item.FullName -ListAvailable
             foreach($localCopy in $localCopies)
            {
              $name = $localCopy.Name
              $source = "$destination\$name"
              #Create package zip
              $path  = $localCopy.ModuleBase
              Compress-Archive -Path "$path\*" -DestinationPath "$source.zip" -Verbose -Force 
              $version = $localCopy.Version.ToString()
              $newName = "$destination\$name" + "_" + "$version" + ".zip"
              # Rename the module folder to contain the version info.
              if(Test-Path($newName))
              {
                  Remove-Item $newName -Recurse -Force 
              }
               Rename-Item -Path "$source.zip" -NewName $newName -Force
            
          } 
        }              
        else
        {
            Write-Host "A different version of the module $name already exists in powershell module path. Please specify -Force to package the module from $source repository. Skipping module from local depot and packaging the version from powershell module path instead." -Fore Red
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
