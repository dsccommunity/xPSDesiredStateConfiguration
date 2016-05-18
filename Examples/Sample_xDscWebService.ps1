# DSC configuration for Pull Server
# Prerequisite: Certificate "CN=PSDSCPullServerCert" in "CERT:\LocalMachine\MY\" store for SSL
# Prerequisite: $RegistrationKey value generated using ([guid]::NewGuid()).Guid
# Note: A Certificate may be generated using MakeCert.exe: http://msdn.microsoft.com/en-us/library/windows/desktop/aa386968%28v=vs.85%29.aspx

configuration Sample_xDscWebService 
{ 
    param  
    ( 
            [string[]]$NodeName = 'localhost', 

            [Parameter(HelpMessage='Use AllowUnencryptedTraffic for setting up a non SSL based endpoint (Recommended only for test purpose)')]
            [ValidateNotNullOrEmpty()] 
            [string] $certificateThumbPrint,

            [Parameter(HelpMessage='This should be a string with enough entropy (randomness) to protect the registration of clients to the pull server.  We will use new GUID by default.')]
            [ValidateNotNullOrEmpty()]
            [string] $RegistrationKey = ([guid]::NewGuid()).Guid
     ) 


     Import-DSCResource -ModuleName xPSDesiredStateConfiguration
     Import-DSCResource -ModuleName PSDesiredStateConfiguration 

     Node $NodeName 
     { 
         WindowsFeature DSCServiceFeature 
         { 
             Ensure = "Present" 
             Name   = "DSC-Service"             
         } 


         xDscWebService PSDSCPullServer 
         { 
             Ensure                  = "Present" 
             EndpointName            = "PSDSCPullServer" 
             Port                    = 8080 
             PhysicalPath            = "$env:SystemDrive\inetpub\PSDSCPullServer" 
             CertificateThumbPrint   = $certificateThumbPrint          
             ModulePath              = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules" 
             ConfigurationPath       = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"             
             State                   = "Started" 
             DependsOn               = "[WindowsFeature]DSCServiceFeature"                         
         } 

        File RegistrationKeyFile
        {
            Ensure          ='Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $RegistrationKey
        }
    }
}
