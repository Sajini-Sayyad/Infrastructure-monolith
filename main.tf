terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote Terraform State
  backend "azurerm" {
    resource_group_name  = "RG"
    storage_account_name = "scss"
    container_name       = "scss-cont"
    key                  = "infrastructure.tfstate"

    use_azuread_auth = true
  }
}

# -----------------------------
# Azure Provider
# -----------------------------

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}

# -----------------------------
# Resource Group
# -----------------------------

resource "azurerm_resource_group" "rg" {
  name     = "rg-terraform-test"
  location = var.location
}

# -----------------------------
# Virtual Network
# -----------------------------

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-terraform-test"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  address_space = ["10.0.0.0/16"]
}

# -----------------------------
# Subnet
# -----------------------------

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-vm"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  address_prefixes = ["10.0.1.0/24"]
}

# -----------------------------
# Public IP
# -----------------------------

resource "azurerm_public_ip" "public_ip" {
  name                = "pip-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
}

# -----------------------------
# Network Security Group
# -----------------------------

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"

    source_port_range          = "*"
    destination_port_range     = "22"

    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# -----------------------------
# Network Interface
# -----------------------------

resource "azurerm_network_interface" "nic" {
  name                = "nic-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# -----------------------------
# Attach NSG to NIC
# -----------------------------

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# -----------------------------
# Linux Virtual Machine
# -----------------------------

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-terraform-test"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  size = "Standard_B2als_v2"

  admin_username = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# -----------------------------
# Azure Container Registry
# -----------------------------

resource "azurerm_container_registry" "acr" {
  name                = "terraformtestacr12345"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  sku           = "Basic"
  admin_enabled = true
}

# -----------------------------
# Storage Account
# -----------------------------

resource "azurerm_storage_account" "storage" {
  name                = "sajiniteststorage01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
}