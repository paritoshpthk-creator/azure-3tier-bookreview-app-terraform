terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Unique suffix for globally unique resources (Key Vault, DB names)
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ------------------------------------------------------------------
# 1. Resource Group
# ------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    Assignment  = "Assignment-06-Three-Tier"
  }
}

# ------------------------------------------------------------------
# 2. Virtual Network & Subnets
# ------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-bookreview-prod"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  tags = azurerm_resource_group.rg.tags
}

# Application Gateway Subnet
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Web/Presentation Tier Subnet
resource "azurerm_subnet" "web_subnet" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# App/Business Tier Subnet
resource "azurerm_subnet" "app_subnet" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Database Tier Subnet (Delegated for PostgreSQL Flexible Server)
resource "azurerm_subnet" "db_subnet" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "fs-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ------------------------------------------------------------------
# 3. Network Security Groups (Least-Privilege Enforcement)
# ------------------------------------------------------------------

# NSG for Web Tier
resource "azurerm_network_security_group" "web_nsg" {
  name                = "nsg-web-tier"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTP-From-AppGW"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.0.0.0/24" # AppGW Subnet
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-Direct-Internet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc" {
  subnet_id                 = azurerm_subnet.web_subnet.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

# NSG for App Tier
resource "azurerm_network_security_group" "app_nsg" {
  name                = "nsg-app-tier"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-AppPort-From-Web"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "10.0.1.0/24" # Web Subnet
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

# NSG for Database Tier
resource "azurerm_network_security_group" "db_nsg" {
  name                = "nsg-db-tier"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-PostgreSQL-From-App"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.0.2.0/24" # App Subnet
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc" {
  subnet_id                 = azurerm_subnet.db_subnet.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

# ------------------------------------------------------------------
# 4. Secret Management (Azure Key Vault)
# ------------------------------------------------------------------
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-bookapp-${random_string.suffix.result}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge"
    ]
  }
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.kv.id
}

# ------------------------------------------------------------------
# 5. Presentation / Web Tier (VM)
# ------------------------------------------------------------------
resource "azurerm_network_interface" "web_nic" {
  name                = "nic-web-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "web_vm" {
  name                            = "vm-web-01"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.web_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/scripts/web_init.sh"))

  tags = azurerm_resource_group.rg.tags
}

# ------------------------------------------------------------------
# 6. Business / Application Tier (VM)
# ------------------------------------------------------------------
resource "azurerm_network_interface" "app_nic" {
  name                = "nic-app-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.10"
  }
}

resource "azurerm_linux_virtual_machine" "app_vm" {
  name                            = "vm-app-01"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.app_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/scripts/app_init.sh"))

  tags = azurerm_resource_group.rg.tags
}

# ------------------------------------------------------------------
# 7. Database Tier (Azure Managed PostgreSQL Flexible Server)
# ------------------------------------------------------------------
resource "azurerm_private_dns_zone" "dns_postgres" {
  name                = "bookapp.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "postgres-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_postgres.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_postgresql_flexible_server" "db" {
  name                   = "psql-bookreview-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "13"
  delegated_subnet_id    = azurerm_subnet.db_subnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.dns_postgres.id
  administrator_login    = var.admin_username
  administrator_password = azurerm_key_vault_secret.db_password.value

  zone = "1"

  storage_mb            = 32768
  sku_name              = "B_Standard_B1ms"
  backup_retention_days = 7

  lifecycle {
    ignore_changes = [zone]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.dns_link]
}

resource "azurerm_postgresql_flexible_server_database" "bookdb" {
  name      = "bookreviewdb"
  server_id = azurerm_postgresql_flexible_server.db.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# ------------------------------------------------------------------
# 8. Controlled Public Entrypoint (Application Gateway v2)
# ------------------------------------------------------------------
resource "azurerm_public_ip" "appgw_pip" {
  name                = "pip-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-bookreview"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name         = "web-backend-pool"
    ip_addresses = [azurerm_network_interface.web_nic.private_ip_address]
  }

  backend_http_settings {
    name                                = "http-setting"
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 30
    probe_name                          = "health-probe"
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "web-backend-pool"
    backend_http_settings_name = "http-setting"
    priority                   = 100
  }

  probe {
    name                                      = "health-probe"
    protocol                                  = "Http"
    path                                      = "/health"
    pick_host_name_from_backend_http_settings = true
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
  }
}

# ------------------------------------------------------------------
# 9. Observability & Diagnostic Log Analytics Workspace
# ------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-bookreview-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}