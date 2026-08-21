# ===================================================================
# AUTOMATED AZURE PORTAL DASHBOARD FOR 3-TIER ARCHITECTURE
# ===================================================================

resource "azurerm_portal_dashboard" "monitoring_dashboard" {
  name                = "dashboard-bookreview-prod"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = azurerm_resource_group.rg.tags

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          # 1. Tile: App Gateway HTTP Request Count
          "0" = {
            position = { x = 0, y = 0, colSpan = 6, rowSpan = 4 }
            metadata = {
              inputs = [
                {
                  name  = "ComponentMetadata"
                  value = {
                    id = azurerm_application_gateway.appgw.id
                  }
                }
              ]
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              settings = {
                content = {
                  chart = {
                    metrics = [
                      {
                        resourceMetadata = { id = azurerm_application_gateway.appgw.id }
                        name             = "TotalRequests"
                        aggregationType  = 1
                      }
                    ]
                    title = "App Gateway - Total Requests"
                  }
                }
              }
            }
          }

          # 2. Tile: Application VM CPU Usage
          "1" = {
            position = { x = 6, y = 0, colSpan = 6, rowSpan = 4 }
            metadata = {
              inputs = [
                {
                  name  = "ComponentMetadata"
                  value = {
                    id = azurerm_linux_virtual_machine.app_vm.id
                  }
                }
              ]
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              settings = {
                content = {
                  chart = {
                    metrics = [
                      {
                        resourceMetadata = { id = azurerm_linux_virtual_machine.app_vm.id }
                        name             = "Percentage CPU"
                        aggregationType  = 4
                      }
                    ]
                    title = "App VM - CPU Percentage"
                  }
                }
              }
            }
          }

          # 3. Tile: PostgreSQL Active Connections
          "2" = {
            position = { x = 0, y = 4, colSpan = 6, rowSpan = 4 }
            metadata = {
              inputs = [
                {
                  name  = "ComponentMetadata"
                  value = {
                    id = azurerm_postgresql_flexible_server.db.id
                  }
                }
              ]
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              settings = {
                content = {
                  chart = {
                    metrics = [
                      {
                        resourceMetadata = { id = azurerm_postgresql_flexible_server.db.id }
                        name             = "active_connections"
                        aggregationType  = 4
                      }
                    ]
                    title = "PostgreSQL - Active Connections"
                  }
                }
              }
            }
          }

          # 4. Tile: Log Analytics KQL Query (Live Access Logs)
          "3" = {
            position = { x = 6, y = 4, colSpan = 6, rowSpan = 4 }
            metadata = {
              inputs = [
                {
                  name  = "resourceTypeMode"
                  value = "components"
                },
                {
                  name  = "ComponentId"
                  value = azurerm_log_analytics_workspace.law.id
                },
                {
                  name  = "Query"
                  value = "AzureDiagnostics | where Category == 'ApplicationGatewayAccessLog' | project TimeGenerated, clientIP_s, httpStatus_d, responseLatency_d | take 10"
                }
              ]
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = {
            relative = {
              duration = 24
              timeUnit = 1
            }
          }
          type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
      }
    }
  })
}