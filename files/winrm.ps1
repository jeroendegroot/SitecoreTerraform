mkdir c:\\scinstall;

$profiles = Get-NetConnectionProfile
Foreach ($i in $profiles) {
    Write-Host ("Updating Interface ID {0} to be Private.." -f $profiles.InterfaceIndex)
    Set-NetConnectionProfile -InterfaceIndex $profiles.InterfaceIndex -NetworkCategory Private
}

Write-Host "Obtaining the Thumbprint of the Certificate from KeyVault"
$Thumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -match "$ComputerName"}).Thumbprint

Write-Host "Enable HTTPS in WinRM.."
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$ComputerName`"; CertificateThumbprint=`"$Thumbprint`"}"

Write-Host "Enabling Basic Authentication.."
winrm set winrm/config/service/Auth "@{Basic=`"true`"}"

Write-Host "Re-starting the WinRM Service"
net stop winrm
net start winrm

Write-Host "Open Firewall Ports"
netsh advfirewall firewall add rule name="Windows Remote Management (HTTPS-In)" dir=in action=allow protocol=TCP localport=5986

Write-Host "Adding Features"
Add-WindowsFeature Web-Asp-Net45;Add-WindowsFeature NET-Framework-45-Core;Add-WindowsFeature Web-Net-Ext45;Add-WindowsFeature Web-ISAPI-Ext;Add-WindowsFeature Web-ISAPI-Filter;Add-WindowsFeature Web-Mgmt-Console;Add-WindowsFeature Web-Scripting-Tools;Add-WindowsFeature Search-Service;Add-WindowsFeature Web-Filtering;Add-WindowsFeature Web-Basic-Auth;Add-WindowsFeature Web-Windows-Auth;Add-WindowsFeature Web-Default-Doc;Add-WindowsFeature Web-Http-Errors;Add-WindowsFeature Web-Static-Content;

Write-Host "Installing prerequisites"


Set-Location C:\scinstall
Invoke-WebRequest -Uri $VCpp -outfile C:\\scinstall\\vc_redist.x64.exe
.\vc_redist.x64.exe /install /passive /norestart

Write-Host "Downloading Sitecore"
Invoke-WebRequest -Uri $ScZip -outfile C:\\scinstall\\sitecore.zip

Write-Host "Creating Site"
Set-Location C:\inetpub\wwwroot
mkdir tfSitecore

expand-archive -path 'C:\\scinstall\\sitecore.zip' -destinationpath 'C:\inetpub\wwwroot\tfSitecore'

$scroot = (Resolve-Path 'C:\inetpub\wwwroot\tfSitecore\Sitecore*' | Select-Object -ExpandProperty Path)[0]

Set-Location C:\windows\system32\inetsrv\
.\appcmd add apppool /name:tfSitecore /managedRuntimeVersion:v4.0 /managedPipelineMode:Integrated
.\appcmd add site /name:tfsitecore /physicalPath:"$scroot\Website" /bindings:http/*:80:$Dnl.$region.cloudapp.azure.com
.\appcmd set app "tfsitecore/" /applicationPool:"tfSitecore"

Write-Host "Create ConnectionStrings.config file"
[xml]$Doc = New-Object System.Xml.XmlDocument
$dec = $Doc.CreateXmlDeclaration("1.0","UTF-8",$null)

$doc.AppendChild($dec) | Out-Null


$text = @" 
    Sitecore connection strings.
    All database connections for Sitecore are configured here.
"@

$doc.AppendChild($doc.CreateComment($text)) | Out-Null

#create root Node
$root = $doc.CreateNode("element","connectionStrings",$null) 

#core DB
$core = $doc.CreateNode("element","add",$null)
$core.SetAttribute("name","core")
$core.SetAttribute("connectionString", "Server=tcp:$dbServer.database.windows.net,1433;Initial Catalog=Sitecore.Core;Persist Security Info=False;User ID=$dbUser;Password=$dbPwd;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;")
$root.AppendChild($core) | Out-Null

#security DB
$security = $doc.CreateNode("element","add",$null)
$security.SetAttribute("name","security")
$security.SetAttribute("connectionString", "Server=tcp:$dbServer.database.windows.net,1433;Initial Catalog=Sitecore.Core;Persist Security Info=False;User ID=$dbUser;Password=$dbPwd;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;")
$root.AppendChild($security) | Out-Null

#master DB
$master = $doc.CreateNode("element","add",$null)
$master.SetAttribute("name","master")
$master.SetAttribute("connectionString", "Server=tcp:$dbServer.database.windows.net,1433;Initial Catalog=Sitecore.Master;Persist Security Info=False;User ID=$dbUser;Password=$dbPwd;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;")
$root.AppendChild($master) | Out-Null

#web DB
$web = $doc.CreateNode("element","add",$null)
$web.SetAttribute("name","web")
$web.SetAttribute("connectionString", "Server=tcp:$dbServer.database.windows.net,1433;Initial Catalog=Sitecore.Web;Persist Security Info=False;User ID=$dbUser;Password=$dbPwd;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;")
$root.AppendChild($web) | Out-Null

$doc.AppendChild($root) | Out-Null

$path = "$scroot\Website\App_Config\ConnectionStrings.config"
Write-Host "Saving connection strings to $Path" -ForegroundColor Green
$doc.save($Path)

Set-Location "$scroot\Website"
mkdir data

Write-Host "Download and set license file"
Invoke-WebRequest -Uri $License -outfile "$scroot\Website\data\license.xml"

Write-Host "Download and set xDB disable config file"
Invoke-WebRequest -Uri $xDbDisable -outfile "$scroot\Website\App_Config\include\xDB.disable.config"

Write-Host "Give app pool permission to site"
$acl = Get-Acl -Path "$scroot"

$ace = New-Object System.Security.Accesscontrol.FileSystemAccessRule ("iis apppool\tfSitecore", "FullControl", "ContainerInherit,ObjectInherit", "InheritOnly", "Allow")
$acl.AddAccessRule($ace)
Set-Acl -Path $scroot -AclObject $acl

Read-Host -Prompt "Setup complete. Press Enter to exit"