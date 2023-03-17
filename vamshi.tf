
##provider

provider "azurerm" {
    features {}

}

## resource group


resource "azurerm_resource_group" "vamshig" {
       name     = local.resource_group
       location = local.location
}

locals {
resource_group = "vamshig"
location       = "east us"
}



# storage account 
variable "azurerm_storage_account" {
  type        = string
  description = "plese enter the storagr account name"
}


resource "azurerm_storage_account" "v_0304" {
  name                            = "vamshistorage073"
  resource_group_name             = local.resource_group
  location                        = local.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = true

  depends_on = [
    azurerm_resource_group.vamshig
  ]
}

#Storage container

resource "azurerm_storage_container" "data" {
       name                  ="data"
       storage_account_name  = "vamshistorage073"
       container_access_type = "blob"
       depends_on = [
         azurerm_storage_account.v_0304
       ]
}


### Storage blob 
resource "azurerm_storage_blob" "sample" {
  name                   = "13.mp4"
  storage_account_name   = "vamshistorage073"
  storage_container_name = "data"
     type                = "Block"
     source              = "13.mp4"
     depends_on = [
       azurerm_storage_container.data
     ]

}

### vnet
resource "azurerm_virtual_network" "app_network" {
  name                = "appnetwork"
  resource_group_name = azurerm_resource_group.vamshig.name
  location            = local.location
  address_space       = ["10.0.0.0/16"]
depends_on = [
  azurerm_resource_group.vamshig
]

}
###subnets
resource "azurerm_subnet" "web" {
  name                 = "web"
  resource_group_name  = local.resource_group
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on           = [
    azurerm_virtual_network.app_network
  ]
}


resource "azurerm_network_interface" "vamshi-nic" {
  name                = "vamshi_nic"
  location            = local.location
  resource_group_name = local.resource_group

  ip_configuration  {
    name                           = "vamshiconf"
    subnet_id                      = azurerm_subnet.web.id
    private_ip_address_allocation  = "Dynamic"
    public_ip_address_id           = azurerm_public_ip.app_public_ip.id
  }
  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_public_ip.app_public_ip,
    azurerm_subnet.web
  ]
}

resource "azurerm_windows_virtual_machine" "appvm1" {
  name                  = "appvm"
  resource_group_name   = local.resource_group
  location              = local.location
  size                  = "Standard_F2"
  admin_username         = "vamshi"
    admin_password      = "Vamshikrishna@123"
  availability_set_id   = azurerm_availability_set.app-set.id
  network_interface_ids = [
    azurerm_network_interface.vamshi-nic.id,
  ]

   os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  depends_on = [
    azurerm_network_interface.vamshi-nic
     
  ]
}



##disk
resource "azurerm_managed_disk" "data-v" {
  name                 = "data_v"
  location             = local.location
  resource_group_name  = local.resource_group
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 16

}

#the we need to attach the data disk to the azure virtual manchine
resource "azurerm_virtual_machine_data_disk_attachment" "data_dk" {
  managed_disk_id      = azurerm_managed_disk.data-v.id
  virtual_machine_id   = azurerm_windows_virtual_machine.appvm1.id
   lun                 = "0"
     caching           = "ReadWrite"
     depends_on = [
    azurerm_windows_virtual_machine.appvm1,
    azurerm_managed_disk.data-v
  ]
}

resource "azurerm_availability_set" "app-set" {
  name                         = "appset"
  location                     = local.location
  resource_group_name          = local.resource_group
  platform_fault_domain_count  = 3
  platform_update_domain_count = 3
  depends_on = [
    azurerm_resource_group.vamshig
  ]
  
}
#network security group

resource "azurerm_network_security_group" "working-ns" {
  name                = "vamshig"
  location            = local.location
  resource_group_name = local.resource_group


## we are creating a rule to allow traffic on port 80

security_rule {
  name                           = "Allow_HTTP"
  priority                       = "300"
  direction                      = "Inbound"
  access                         = "Allow"
  protocol                       = "Tcp"
  source_port_range              = "*"
  destination_port_range         = "80"
  source_address_prefix          = "*"
  destination_address_prefix     = "*"
  }


}
resource "azurerm_subnet_network_security_group_association" "vamshi_association" {
  subnet_id                     = azurerm_subnet.web.id
  network_security_group_id     = azurerm_network_security_group.working-ns.id

  depends_on = [
    azurerm_network_security_group.working-ns
       ]
  }

  ###ip adress 
  resource "azurerm_public_ip" "app_public_ip" {
  name                = "app-public-ip"
  resource_group_name = local.resource_group
  location            = local.location
  allocation_method   = "Static"
  depends_on = [
    azurerm_resource_group.vamshig
  ]
}

###sql database 
resource "azurerm_sql_server" "mania-sv" {
  name                         = "maniashi"
  resource_group_name          = local.resource_group
  location                     = local.location
  version                      = "12.0"
  administrator_login          = "vamshi"
  administrator_login_password = "Vamsi@123"

}

resource "azurerm_sql_database" "sql-vms" {
  name                = "sqldatabase"
  resource_group_name = local.resource_group
  location            = local.location
  server_name         = azurerm_sql_server.mania-sv.name

  depends_on = [
    azurerm_sql_server.mania-sv
  ]
}
resource "azurerm_sql_firewall_rule" "mania-firewall" {
  name                = "maniafirewall"
  resource_group_name = local.resource_group
  server_name         = azurerm_sql_server.mania-sv.name
  start_ip_address    = "183.83.38.221"
  end_ip_address      = "183.83.38.221"
}

##linux
resource "azurerm_linux_virtual_machine" "lxvms" {
  name                          = "manialinux"
  resource_group_name           = local.resource_group
  location                      = local.location
  size                          = "Standard_B1s"
  admin_username                = "vamshi"
  admin_password                = "Vamshikrishna@123"
  network_interface_ids         = [ azurerm_network_interface.vamshi-nic.id]
disable_password_authentication = false
  

  os_disk {
    caching                     = "ReadWrite"
    storage_account_type        = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  
}
