terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  required_version = ">= 1.4.5"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resource_group" {
  name     = "automation"
  location = "West Europe"
  tags = {
    "usage" = "automation"
  }
}

resource "azurerm_application_security_group" "security_group" {
  name                = "automation"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  tags = {
    "usage" = "automation"
  }
}

resource "azurerm_virtual_network" "network" {
  name                = "automation"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.0.0.0/24"]

  tags = {
    "usage" = "automation"
  }
}

resource "azurerm_subnet" "automation_1" {
  name                 = "automation_1"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.0.0.0/25"]
}

resource "azurerm_subnet" "automation_2" {
  name                 = "automation_2"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.0.0.128/25"]
}

resource "azurerm_network_security_rule" "vm_access" {
  name                        = "inbound_access"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_ranges     = ["80", "443", "22"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.resource_group.name
  network_security_group_name = azurerm_application_security_group.security_group.name
}

resource "azurerm_network_interface" "linux_vm" {
  name                = "linux_vm"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "linux_vm"
    subnet_id                     = azurerm_subnet.automation_1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "linux_vm" {
  name                = "automation_machine_1"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  size                = "Standard_B1s"
  admin_username      = "automation_admin"
  network_interface_ids = [
    azurerm_network_interface.linux_vm.id
  ]
  admin_ssh_key {
    username   = "automation_admin"
    public_key = file("./keys/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}