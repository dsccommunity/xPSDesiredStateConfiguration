# DSCPullServer contains utilities to automate DSC module and configuration document packaging and delpoyment on enterprise pull server , and examples

# Publish-DSCModuleAndMof cmdlet
   Use Publish-DSCModuleAndMof cmdlet to package DSC modules that present in $Source or in $ModuleNameList into zip files with the version info and publish them with mof configuration documents that present in $Source on Pull server. 
   Publishes the modules on "$env:ProgramFiles\WindowsPowerShell\DscService\Modules"
   Publishes all mof configuration documents on "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"
   Use $Force to force packaging the version that exists in $Source folder if a different version of the module exists in powershell module path
   Use $ModuleNameList to specify the names of the modules to be published (all versions if multiple versions of the module are installed) if no DSC module presents in local folder $Source

.EXAMPLE
    Publish-DSCModuleAndMof -Source C:\LocalDepot
       
.EXAMPLE
    $moduleList = @("xWebAdministration", "xPhp")
    Publish-DSCModuleAndMof -Source C:\LocalDepot -ModuleNameList $moduleList

.EXAMPLE
    Publish-DSCModuleAndMof -Source C:\LocalDepot -Force
    
    
 
# How to Configure Pull Server & SQL Server to enable new SQL backend provider feature in DSC

- Install SQL Server on a clean OS 
- On the SQL Server Machine:   
	- Create a Firewall rule according to this link : https://technet.microsoft.com/en-us/library/ms175043(v=sql.110).aspx
	
   - Enable TCP/IP :
      - Open "SQL Server Configuration Manager"
      - Now Click on "SQL Server Network Configuration" and Click on "Protocols for Name" 
      - Right Click on "TCP/IP" (make sure it is Enabled) Click on Properties 
      - Now Select "IP Addresses" Tab -and- Go to the last entry "IP All" 
      - Enter "TCP Port" 1433. 
      - Now Restart "SQL Server .Name." using "services.msc" (winKey + r)
    
    - Enable Remote Connections to the SQL Server 
      - Go to Server Properties 
      - Select Connections 
      - Under the Remote server connections - Click the check box next to "Allow remote connections to this server"
	
    - Create a new User login (This is required as the engine will need this privilege to create the DSC DB and tables) 
      - Go to the Login Properties 
      - Select Server Roles - select "Public" and "Sysadmin"      
      - Select User Mapping - select "db_owner" and "public" 

		
- On the Pull Server 
	- Update the Web.Config with the SQL server connection string
         -  Open : C:\inetpub\wwwroot\PSDSCPullServer\Web.config
         - &lt;add key="dbprovider" value="System.Data.OleDb"/&gt;
         - &lt;add key="dbconnectionstr" value="Provider=SQLNCLI11;Data Source=<ServerName>;Initial Catalog=master;User ID=sa;Password=<sapassword>;Initial Catalog=master;"/&gt;
         - If SQL server was installed as a named Instance instead of default one then use 
         - &lt;add key="dbconnectionstr" value="Provider=SQLNCLI11;Data Source=<ServerName>\<InstanceName>;Initial Catalog=master;User ID=sa;Password=<sapassword>;Initial Catalog=master;"/&gt;
      
	- Run iireset for the Pull server to pick up the new configuration.
