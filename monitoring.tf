# ===================================================================
# AZURE MONITORING & LOG ANALYSIS CONFIGURATION
# ===================================================================

# -------------------------------------------------------------------
# 1. Diagnostic Settings - Application Gateway v2
# Capture Inbound HTTP Access Logs, WAF Logs, and Gateway Metrics
# -------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "appgw_diag" {
  name                       = "diag-appgw-bookreview"
  target_resource_id         = azurerm_application_gateway.appgw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
  }
}

# -------------------------------------------------------------------
# 2. Diagnostic Settings - PostgreSQL Flexible Server
# Capture Database Execution Logs, Errors, Connection & Storage Metrics
# -------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "db_diag" {
  name                       = "diag-psql-bookreview"
  target_resource_id         = azurerm_postgresql_flexible_server.db.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

# -------------------------------------------------------------------
# 3. Diagnostic Settings - Key Vault
# Capture Key Vault Audit Logs (Secret Access, Auth Requests)
# -------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "kv_diag" {
  name                       = "diag-kv-bookreview"
  target_resource_id         = azurerm_key_vault.kv.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
  }
}

# -------------------------------------------------------------------
# 4. Azure Monitor Agent (AMA) Extensions for VMs
# Push System/OS Metrics and Syslog from VMs to Log Analytics
# -------------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "web_vm_ama" {
  name                       = "AzureMonitorLinuxAgent-WebVM"
  virtual_machine_id         = azurerm_linux_virtual_machine.web_vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.25"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "app_vm_ama" {
  name                       = "AzureMonitorLinuxAgent-AppVM"
  virtual_machine_id         = azurerm_linux_virtual_machine.app_vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.25"
  auto_upgrade_minor_version = true
}

# -------------------------------------------------------------------
# 5. Action Group for Automated Notifications
# Send Email Alerts on Critical Infrastructure Failures
# -------------------------------------------------------------------
resource "azurerm_monitor_action_group" "devops_alerts" {
  name                = "ag-devops-notifications"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "devops-ag"

  email_receiver {
    name                    = "DevOpsOpsTeam"
    email_address           = "devops-alerts@example.com" # Apni Email ID yahan replace karein
    use_common_alert_schema = true
  }
}

# -------------------------------------------------------------------
# 6. Metric Alerts - Application Gateway Backend Unhealthy
# -------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "appgw_unhealthy" {
  name                = "alert-appgw-unhealthy-backend"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_application_gateway.appgw.id]
  description         = "Triggers when App Gateway backend VM becomes unhealthy."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.devops_alerts.id
  }
}

# -------------------------------------------------------------------
# 7. Metric Alerts - High CPU Usage on Application VM
# -------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "app_vm_cpu" {
  name                = "alert-app-vm-high-cpu"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.app_vm.id]
  description         = "Triggers when App VM CPU usage exceeds 85% for 5 minutes."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.devops_alerts.id
  }
}