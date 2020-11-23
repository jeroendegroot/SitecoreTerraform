//Start variables which need to be populated from tfvars file, please populate these with your own values
variable "StorageKey" {
  description = "Storage key for bacpac files"  
}

variable "LicenseFile" {
  description = "Location of the Sitecore license.xml file"  
}

variable "BacpacCoreDB" {
  description = "Location of the bacpac of the Sitecore core DB"  
}

variable "BacpacMasterDB" {
  description = "Location of the bacpac of the Sitecore master DB"  
}

variable "BacpacWebDB" {
  description = "Location of the bacpac of the Sitecore web DB"  
}

variable "VCppPackage" {
  description = "Location of the Visual C++ Redistributable package"  
}

variable "SitecoreZip" {
  description = "Location of the Zipped Sitecore installer file"  
}

variable "DomainNameLabel" {
  description = "Domain name label of the public IP, will make site accesible under DomainNameLabel.region.cloudapp.azure.com"  
}

variable "xDbDisableFile" {
  description = "File to disable xDB, can also be used to patch in other settings"  
}

//End variables which need to be populated from tfvars file

variable "location" {
  description = "The Azure Region in which the resources in this example should exist"
  default = "centralus"
}

variable "prefix" {
  description = "The Prefix used for all resources in this example"
  default = "sitecore"
}

variable "virtualMachineName" {
  description = "The virtual machine name"
  default = "sitecore-vm"
}

variable "vmAdminUser" {
  description = "The admin user of virtual machine"
  default = "testadmin"
}

variable "vmAdminPassword" {
  description = "The admin password of virtual machine"
  default = "Password1234!"
}

variable "SqlServerName" {
  description = "The name of the Azure SQL Server to be created or to have the database on - needs to be unique, lowercase between 3 and 24 characters including the prefix"
  default     = "tfsitecoresym19"
}

variable "SQLServerAdminUser" {
  description = "The name of the Azure SQL Server Admin user for the Azure SQL Database"
  default     = "scadmin"
}
variable "SQLServerAdminPassword" {
  description = "The Azure SQL Database users password"
  default     = "dRe4uBlcHlra8h"
}

variable "Edition" {
  description = "The Edition of the Database - Basic, Standard, Premium, or DataWarehouse"
  default     = "Standard"
}

variable "ServiceObjective" {
  description = "The Service Tier S0, S1, S2, S3, P1, P2, P4, P6, P11 and ElasticPool"
  default     = "S0"
}