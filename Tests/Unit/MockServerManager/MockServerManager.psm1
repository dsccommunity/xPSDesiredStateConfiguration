<#
 #  Powershell mock module for Servermanager that creates a pseudo cmdlet for Add-WindowsFeature, Remove-WindowsFeature and Get-WindowsFeature
 #  Each of these cmdlets will manipulate a global object (defined at the end of this module), instead of performing their original actions.
 #  
 #>
function Add-WindowsFeature
{
    [CmdletBinding()]
    param(

        [System.Object]
        ${Vhd},

        [switch]
        ${IncludeAllSubFeature},

        [parameter(Position=0)]
        [System.Object]
        ${Name},

        [switch]
        ${Restart},

        [switch]
        ${IncludeManagementTools},

        [System.Object]
        ${Credential},

        [System.Object]
        ${ConfigurationFilePath},

        [Alias('Cn')]
        [System.Object]
        ${ComputerName},

        [System.Object]
        ${Source},

        [System.Object]
        ${LogPath})


    begin
    {
        try 
        {
            $useActualWindowsFeature=$false
                if( $Name -eq $null -or
                    $ComputerName -ne $null -or #This would mean you want to connect to another computer 
                    $Global:MockFeatures[$Name] -eq $null -or #In the case the feature doesn't exist in the given mock features (error wont take time)
                    $Restart -or
                    $Vhd -ne $null -or
                    $ConfigurationFilePath -ne $null  -or
                    $Source -ne $null -or
                    $LogPath -ne $null -or
                    $IncludeManagementTools) 
                {
                    $useActualWindowsFeature=$true
                }
                if($useActualWindowsFeature)
                {
                    import-module "$pshome\modules\servermanager"
                    $outBuffer = $null
                    if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
                    {
                        $PSBoundParameters['OutBuffer'] = 1
                    }
                    $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('servermanager\Add-WindowsFeature', [System.Management.Automation.CommandTypes]::Cmdlet)
                    $scriptCmd = {& $wrappedCmd @PSBoundParameters }
                    $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
                    $steppablePipeline.Begin($PSCmdlet)
                    remove-module "$pshome\modules\servermanager" -ea Ignore
                }
                else
                {
                    if($Credential -ne $null)
                    {
                        $Users = $Credential.UserName
                        $pass=$Credential.GetNetworkCredential().password
                        Add-Type -assemblyname System.DirectoryServices.AccountManagement 
                        $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
                        $validID=$DS.ValidateCredentials($Users, $pass)
   		        $DS.Dispose()
			$DS = $null
                        if($validID -eq $false)
                        {
                            throw "Invalid credentials $Users $pass"
                        }
			
                    }
                    $changeMade=$false
                    $featureResult=@()
                    $exitCode="NoChangeNeeded"
                    if($Global:MockFeatures[$Name].Installed -eq $false)
                    {
                        $Global:MockFeatures[$Name].Installed=$true
                        $changeMade=$true
                        $featureResult+= $Name
                        
                    }
                    if($IncludeAllSubFeature)
                    {
                        foreach($i in $Global:MockFeatures[$Name].SubFeatures)
                        {
                            if($Global:MockFeatures[$i].Installed -eq $false)
                            {
                                $Global:MockFeatures[$i].Installed=$true
                                $changeMade=$true
                                $featureResult+= $i 
                            }
                        }
                    }
                    if($changeMade)
                    {
                        $exitCode="Success"
                    }
                    $thisFeature= @{"Success"=$true;"RestartNeeded"="no";"FeatureResult"=$featureResult;"ExitCode"=$exitCode}
                    $outputObject =New-Object psobject -Property $thisFeature
                    $outputObject.pstypenames[0] = "Microsoft.Windows.ServerManager.Commands.FeatureOperationResult"
            
                    $outputObject
                }

        } 
        catch 
        {
            throw
        }
    }

    process
    {
        try 
        {
            if($useActualWindowsFeature)
                {
                    $steppablePipeline.Process($_)
                }
            else
            {
            
            }
        } 
        catch 
        {
            throw
        }
    } 

    end
    {
        try 
        {
            if($useActualWindowsFeature)
                {
                    $steppablePipeline.End()
                }
        } 
        catch 
        {
            throw
        }
    }
    <#

    .ForwardHelpTargetName Install-WindowsFeature
    .ForwardHelpCategory Function

    #>

}

function Get-WindowsFeature
{
    [CmdletBinding()]

    param(
        [System.Object]
        ${Vhd},

        [parameter(Position=1)]
        [System.Object]
        ${Name},

        [System.Object]
        ${Credential},

        [Alias('Cn')]
        [System.Object]
        ${ComputerName},


        [System.Object]
        ${LogPath}
        )

    begin
    {
    
        $useActualWindowsFeature=$false
       try 
       {
            if($Vhd -ne $null -or
               $ComputerName -ne $null -or
               $LogPath -ne $null -or
               $Global:MockFeatures[$Name] -eq $null
               )
            {
                $useActualWindowsFeature=$true
            }
            if($useActualWindowsFeature)
            {
                Import-Module "$pshome\modules\servermanager"
            
                $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('servermanager\Get-WindowsFeature', [System.Management.Automation.CommandTypes]::Function)
                #$PSBoundParameters.Add('$args', $args)
                $scriptCmd = {& $wrappedCmd @PSBoundParameters }
                $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
                $steppablePipeline.Begin($myInvocation.ExpectingInput, $ExecutionContext)
                remove-module "$pshome\modules\servermanager" -ea Ignore
            }
            else
            {
                if($Credential -ne $null)
                {
                    $Users = $Credential.UserName
                    $pass=$Credential.GetNetworkCredential().password
                    Add-Type -assemblyname System.DirectoryServices.AccountManagement 
                    $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
                    $validID=$DS.ValidateCredentials($Users, $pass)
                    $DS.Dispose()
		    $DS  = $null
		    if($validID -eq $false)
                    {
                        throw "Invalid credentials"
                    }
                }
                $thisFeature= $Global:MockFeatures[$Name]
                $outputObject =New-Object psobject -Property $thisFeature
                $outputObject.pstypenames[0] = "Microsoft.Windows.ServerManager.Commands.Feature"
            
                $outputObject
            }
        } 
        catch 
        {
            throw
        }
    }

    process
    {
        try 
        {
            if($useActualWindowsFeature)
            {
                Import-Module "$pshome\modules\servermanager"
            
                $steppablePipeline.Process($_)
                remove-module "$pshome\modules\servermanager" -ea Ignore
            }
        } catch {
            throw
        }
    }

    end
    {
        try 
        {
            if($useActualWindowsFeature)
            {
                Import-Module "$pshome\modules\servermanager"
                $steppablePipeline.End()
                remove-module "$pshome\modules\servermanager" -ea Ignore
            }
        } 
        catch 
        {
            throw
        }
    }
    <#

    .ForwardHelpTargetName Get-WindowsFeature
    .ForwardHelpCategory Function

#>
}

function Remove-WindowsFeature
{
    [CmdletBinding(DefaultParameterSetName='RunningComputer', SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        ${Name},

        [Parameter(ParameterSetName='VhdPath')]
        [ValidateNotNullOrEmpty()]
        [string]
        ${Vhd},

        [Parameter(ParameterSetName='RunningComputer')]
        [switch]
        ${Restart},

        [Parameter(ParameterSetName='VhdPath')]
        [Parameter(ParameterSetName='RunningComputer')]
        [switch]
        ${IncludeManagementTools},

        [switch]
        ${Remove},

        [Alias('Cn')]
        [ValidateNotNullOrEmpty()]
        [string]
        ${ComputerName},

        [ValidateNotNullOrEmpty()]
        [pscredential]
        [System.Management.Automation.CredentialAttribute()]
        ${Credential},

        [ValidateNotNullOrEmpty()]
        [string]
        ${LogPath})

    begin
    {
        try {
            $useActualWindowsFeature=$false
            if( $Name -eq $null -or
                $ComputerName -ne "" -or #This would mean you want to connect to another computer 
                $Global:MockFeatures[$Name] -eq $null -or #In the case the feature doesn't exist in the given mock features (error wont take time)
                $Restart -or
                $Vhd -ne "" -or
                $Remove -or
                $LogPath -ne "" -or
                $IncludeManagementTools ) 
            {
                $useActualWindowsFeature=$true
            }
            if($useActualWindowsFeature)
            {
                import-module "$pshome\modules\servermanager"
                $outBuffer = $null
                if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
                {
                    $PSBoundParameters['OutBuffer'] = 1
                }
                $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('servermanager\Uninstall-WindowsFeature', [System.Management.Automation.CommandTypes]::Cmdlet)
                $scriptCmd = {& $wrappedCmd @PSBoundParameters }
                $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
                $steppablePipeline.Begin($PSCmdlet)
                remove-module "$pshome\modules\servermanager" -ea Ignore
            }
            else
            {
                
                if($Credential -ne $null)
                {
                    $Users = $Credential.UserName
                    $pass=$Credential.GetNetworkCredential().password
                    Add-Type -assemblyname System.DirectoryServices.AccountManagement 
                    $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
                    $validID=$DS.ValidateCredentials($Users, $pass)
                    $DS.Dispose()
		    $DS= $null
		    if($validID -eq $false)
                    {
                        throw "Invalid credentials"
                    }
                }
                $changeMade=$false
                $featureResult=@()
                $exitCode="NoChangeNeeded"
                if($Global:MockFeatures[$Name].Installed -eq $true)
                {
                    $Global:MockFeatures[$Name].Installed=$false
                    $changeMade=$true
                    $featureResult+=$Name
                }
                foreach($i in $Global:MockFeatures[$Name].SubFeatures)
                    {
                        if($Global:MockFeatures[$i].Installed -eq $true)
                            {
                                $Global:MockFeatures[$i].Installed=$false
                                $changeMade=$true
                                $featureResult+=$i
                            }
                    }
                
                if($changeMade)
                {
                    $exitCode="Success"
                }
                $thisFeature= @{"Success"=$true;"RestartNeeded"="no";"FeatureResult"=$featureResult;"ExitCode"=$exitCode}
                $outputObject =New-Object psobject -Property $thisFeature
                $outputObject.pstypenames[0] = "Microsoft.Windows.ServerManager.Commands.FeatureOperationResult"
            
                $outputObject
                     
            }
        } catch {
            throw
        }
    }

    process
    {
        try {
            if($useActualWindowsFeature)
            {
                $steppablePipeline.Process($_)
            }
        } catch {
            throw
        }
    }

    end
    {
        try {
            if($useActualWindowsFeature)
            {
                $steppablePipeline.End()
            }
        } catch {
            throw
        }
    }
}


#region MockFeatures
<#
 #   Region for defining the global hash variable begins here. The following mock objects are of type as output from servermanager/Get-windowsfeature
 #   cmdlet.
 #>

$Global:hashFeatureTest1= @{ 
    "Name"                      = "Test1";
    "DisplayName"               = "Test Feature 1";
    "Description"               = "Test Feature with 3 subfeatures";
    "Installed"                 = $false ;
    "InstallState"              = "Available" ;
    "FeatureType"               = "Role Service";
    "Path"                      = "Test1";
    "Depth"                     = 1;#This is its level from the top
    "DependsOn"                 = @();
    "Parent"                    = ""; #since it doesn't have a parent
    "ServerComponentDescriptor" ="ServerComponent_Test_Cert_Authority";
    "SubFeatures"               = @("SubTest1","SubTest2","SubTest3");
    "SystemService"             = @();
    "Notification"              = @();
    "BestPracticesModelId"      = $null;
    "EventQuery"                = $null;
    "PostConfigurationNeeded"   = $false;
    "AdditionalInfo"            = @("MajorVersion", "MinorVersion", "NumericId", "InstallName");
        }

$Global:hashFeatureTestSub1= @{ 
    "Name"                      = "SubTest1";
    "DisplayName"               = "Sub Test Feature 1";
    "Description"               = "Sub Test Feature with parent as test1";
    "Installed"                 = $false ;
    "InstallState"              = "Available" ;
    "FeatureType"               = "Role Service";
    "Path"                      = "Test1\SubTest1";
    "Depth"                     = 2;#This is its level from the top
    "DependsOn"                 = @();
    "Parent"                    = "Test1"; #since it doesn't have a parent
    "ServerComponentDescriptor" =$null;
    "SubFeatures"               = @();
    "SystemService"             = @();
    "Notification"              = @();
    "BestPracticesModelId"      = $null;
    "EventQuery"                = $null;
    "PostConfigurationNeeded"   = $false;
    "AdditionalInfo"            = @("MajorVersion", "MinorVersion", "NumericId", "InstallName");
        }

$Global:hashFeatureTestSub2= @{ 
    "Name"                      = "SubTest2";
    "DisplayName"               = "Sub Test Feature 2";
    "Description"               = "Sub Test Feature with parent as test1";
    "Installed"                 = $false ;
    "InstallState"              = "Available" ;
    "FeatureType"               = "Role Service";
    "Path"                      = "Test1\SubTest2";
    "Depth"                     = 2;#This is its level from the top
    "DependsOn"                 = @();
    "Parent"                    ="Test1"; #since it doesn't have a parent
    "ServerComponentDescriptor" =$null;
    "SubFeatures"               = @();
    "SystemService"             = @();
    "Notification"              = @();
    "BestPracticesModelId"      = $null;
    "EventQuery"                = $null;
    "PostConfigurationNeeded"   = $false;
    "AdditionalInfo"            = @("MajorVersion", "MinorVersion", "NumericId", "InstallName");
        }

$Global:hashFeatureTestSub3= @{ 
    "Name"                      = "SubTest3";
    "DisplayName"               = "Sub Test Feature 3";
    "Description"               = "Sub Test Feature with parent as test1";
    "Installed"                 = $false ;
    "InstallState"              = "Available" ;
    "FeatureType"               = "Role Service";
    "Path"                      = "Test\SubTest3";
    "Depth"                     = 2;#This is its level from the top
    "DependsOn"                 = @();
    "Parent"                    = "Test1"; #since it doesn't have a parent
    "ServerComponentDescriptor" =$null;
    "SubFeatures"               = @();
    "SystemService"             = @();
    "Notification"              = @();
    "BestPracticesModelId"      = $null;
    "EventQuery"                = $null;
    "PostConfigurationNeeded"   = $false;
    "AdditionalInfo"            = @("MajorVersion", "MinorVersion", "NumericId", "InstallName");
        }

$Global:MockFeatures =@{
    $Global:hashFeatureTest1["Name"]=$Global:hashFeatureTest1;
    $Global:hashFeatureTestSub1["Name"]= $Global:hashFeatureTestSub1;
    $Global:hashFeatureTestSub2["Name"]=$Global:hashFeatureTestSub2;
    $Global:hashFeatureTestSub3["Name"]=$Global:hashFeatureTestSub3;}

#endregion