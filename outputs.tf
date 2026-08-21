output "resource_group_name" {
  description = "The deployed Resource Group name"
  value       = azurerm_resource_group.rg.name
}

output "public_entrypoint_ip" {
  description = "Public IP Address of Application Gateway (Public Entry Point)"
  value       = azurerm_public_ip.appgw_pip.ip_address
}

output "public_app_url" {
  description = "Public Application URL"
  value       = "http://${azurerm_public_ip.appgw_pip.ip_address}"
}

output "web_tier_private_ip" {
  description = "Internal IP of the Web Tier VM"
  value       = azurerm_network_interface.web_nic.private_ip_address
}

output "app_tier_private_ip" {
  description = "Internal IP of the Application Tier VM"
  value       = azurerm_network_interface.app_nic.private_ip_address
}

output "postgresql_fqdn" {
  description = "Fully Qualified Domain Name of Private Database Server"
  value       = azurerm_postgresql_flexible_server.db.fqdn
}

output "key_vault_name" {
  description = "Key Vault Name for Secret Management"
  value       = azurerm_key_vault.kv.name
}