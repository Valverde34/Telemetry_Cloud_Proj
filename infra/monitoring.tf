# Monitoring and alerting with Azure Monitor:
#   - Log Analytics: logs of every container (stdout/stderr)
#   - Availability test: calls /health/data every 5 min from 3 European locations
#   - Alerts by email: pipeline down, API errors, database CPU/storage

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
}

resource "azurerm_monitor_action_group" "email" {
  name                = "ag-${var.project}-email"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "telemetry"

  email_receiver {
    name                    = "owner"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# /health/data returns 503 when no reading arrived in the last 2 minutes, so
# this single test covers the whole chain: simulator -> broker -> API -> DB.
resource "azurerm_application_insights_standard_web_test" "pipeline" {
  name                    = "webtest-${var.project}-pipeline"
  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  application_insights_id = azurerm_application_insights.main.id
  geo_locations           = ["emea-nl-ams-azr", "emea-gb-db3-azr", "emea-fr-pra-edge"]
  frequency               = 300
  timeout                 = 30
  enabled                 = true

  request {
    url = "https://${azurerm_container_app.api.ingress[0].fqdn}/health/data"
  }

  validation_rules {
    expected_status_code        = 200
    ssl_check_enabled           = true
    ssl_cert_remaining_lifetime = 7
  }
}

resource "azurerm_monitor_metric_alert" "pipeline_down" {
  name                = "alert-${var.project}-pipeline-down"
  resource_group_name = azurerm_resource_group.main.name
  description         = "No fresh readings: /health/data failing from 2+ locations."
  severity            = 1

  scopes = [
    azurerm_application_insights_standard_web_test.pipeline.id,
    azurerm_application_insights.main.id,
  ]

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.pipeline.id
    component_id          = azurerm_application_insights.main.id
    failed_location_count = 2
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}

resource "azurerm_monitor_metric_alert" "api_5xx" {
  name                = "alert-${var.project}-api-5xx"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_container_app.api.id]
  description         = "The API returned more than 5 server errors (5xx) in 5 minutes."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5

    dimension {
      name     = "statusCodeCategory"
      operator = "Include"
      values   = ["5xx"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}

resource "azurerm_monitor_metric_alert" "db_cpu" {
  name                = "alert-${var.project}-db-cpu"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "Database CPU above 80% for 15 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}

resource "azurerm_monitor_metric_alert" "db_storage" {
  name                = "alert-${var.project}-db-storage"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "Database storage above 80%."
  severity            = 2
  frequency           = "PT15M"
  window_size         = "PT1H"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}
