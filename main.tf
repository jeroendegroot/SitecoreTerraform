# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=2.37.0"
  features {}
}

#load the correct PS variables for the WinRM script which configures Sitecore
locals {
  custom_data_params  = "Param($ComputerName = \"${var.virtualMachineName}\", $dbServer = \"${azurerm_sql_server.sitecoredbs.name}\", $dbUser = \"${var.SQLServerAdminUser}\", $dbPwd = \"${var.SQLServerAdminPassword}\", $VCpp = \"${var.VCppPackage}\", $ScZip = \"${var.SitecoreZip}\", $Dnl = \"${var.DomainNameLabel}\", $Region = \"${var.location}\", $License = \"${var.LicenseFile}\", $xDbDisable = \"${var.xDbDisableFile}\" )"
  custom_data_content = "${local.custom_data_params} ${file("./files/winrm.ps1")}" 
}

#network resources
resource "azurerm_resource_group" "sitecoresym" {
  name     = "${var.prefix}-resources"
  location = var.location
}

resource "azurerm_virtual_network" "sitecoresym" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.sitecoresym.location
  resource_group_name = azurerm_resource_group.sitecoresym.name
}

resource "azurerm_subnet" "sitecoresym" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.sitecoresym.name
  virtual_network_name = azurerm_virtual_network.sitecoresym.name
  address_prefixes       =  ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "sitecoresym" {
  name                = "${var.prefix}-publicip"
  resource_group_name = azurerm_resource_group.sitecoresym.name
  location            = azurerm_resource_group.sitecoresym.location
  allocation_method   = "Static"
  domain_name_label   = var.DomainNameLabel
}

resource "azurerm_network_interface" "sitecoresym" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.sitecoresym.location
  resource_group_name = azurerm_resource_group.sitecoresym.name

  ip_configuration {
    name                          = "configuration"
    subnet_id                     = azurerm_subnet.sitecoresym.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.sitecoresym.id
  }
}

#database resources
resource "azurerm_sql_server" "sitecoredbs" {
  name                         = var.SqlServerName
  resource_group_name          = azurerm_resource_group.sitecoresym.name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.SQLServerAdminUser
  administrator_login_password = var.SQLServerAdminPassword   
}

#firewall rule to allow access to DB feom other Azure services
resource "azurerm_sql_firewall_rule" "sitecoredbs" {
  name                = "Allow access to Azure services"
  resource_group_name = azurerm_resource_group.sitecoresym.name
  server_name         = azurerm_sql_server.sitecoredbs.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurerm_sql_database" "sitecoredbs_core" {
  name                              = "Sitecore.Core"
  resource_group_name               = azurerm_resource_group.sitecoresym.name
  location                          = var.location
  server_name                       = azurerm_sql_server.sitecoredbs.name
  edition                           = var.Edition
  requested_service_objective_name  = var.ServiceObjective
 
  import {
      storage_uri                   = var.BacpacCoreDB
      storage_key                   = var.StorageKey
      storage_key_type              = "StorageAccessKey"
      administrator_login           = var.SQLServerAdminUser
      administrator_login_password  = var.SQLServerAdminPassword
      authentication_type           = "SQL"
  }
}

resource "azurerm_sql_database" "sitecoredbs_master" {
  name                              = "Sitecore.Master"
  resource_group_name               = azurerm_resource_group.sitecoresym.name
  location                          = var.location
  server_name                       = azurerm_sql_server.sitecoredbs.name
  edition                           = var.Edition
  requested_service_objective_name  = var.ServiceObjective
 
  import {
      storage_uri                   = var.BacpacMasterDB
      storage_key                   = var.StorageKey
      storage_key_type              = "StorageAccessKey"
      administrator_login           = var.SQLServerAdminUser
      administrator_login_password  = var.SQLServerAdminPassword
      authentication_type           = "SQL"
  }
}

resource "azurerm_sql_database" "sitecoredbs_web" {
  name                              = "Sitecore.Web"
  resource_group_name               = azurerm_resource_group.sitecoresym.name
  location                          = var.location
  server_name                       = azurerm_sql_server.sitecoredbs.name
  edition                           = var.Edition
  requested_service_objective_name  = var.ServiceObjective
 
  import {
      storage_uri                   = var.BacpacWebDB
      storage_key                   = var.StorageKey
      storage_key_type              = "StorageAccessKey"
      administrator_login           = var.SQLServerAdminUser
      administrator_login_password  = var.SQLServerAdminPassword
      authentication_type           = "SQL"
  }
}

resource "azurerm_virtual_machine" "sitecoresym" {
  name                  = var.virtualMachineName
  location              = azurerm_resource_group.sitecoresym.location
  resource_group_name   = azurerm_resource_group.sitecoresym.name
  network_interface_ids = [azurerm_network_interface.sitecoresym.id]
  vm_size               = "Standard_DS2_V2"

  # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku  = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.prefix}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = var.virtualMachineName
    admin_username = var.vmAdminUser
    admin_password = var.vmAdminPassword
    custom_data    = local.custom_data_content
  }
  
  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true

    # Auto-Login's required to configure WinRM
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${var.vmAdminUser}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.vmAdminPassword}</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = file("./files/FirstLogonCommands.xml")
    }   
  }
}

##################################################################################
# OUTPUT
##################################################################################

output "azure_instance_public_" {
    value = azurerm_public_ip.sitecoresym.ip_address
}