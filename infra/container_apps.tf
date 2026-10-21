# Azure Container Apps: runs our three containers (broker, API, simulator)
# without managing servers. The environment is connected to snet-app, so the
# apps can reach PostgreSQL over the private network.

resource "random_password" "mqtt_api" {
  length  = 32
  special = false
}

resource "random_password" "mqtt_simulator" {
  length  = 32
  special = false
}

# The infrastructure resource group is created and managed by Azure itself.
# The load balancer is public because the API has a public HTTPS URL; the
# broker stays internal (see its ingress below).
resource "azurerm_container_app_environment" "main" {
  name                               = "cae-${var.project}"
  location                           = azurerm_resource_group.main.location
  resource_group_name                = azurerm_resource_group.main.name
  logs_destination                   = "log-analytics"
  log_analytics_workspace_id         = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id           = azurerm_subnet.app.id
  infrastructure_resource_group_name = "rg-${var.project}-cae-infra"
  internal_load_balancer_enabled     = false

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

locals {
  image_prefix = "ghcr.io/${var.ghcr_owner}/telemetry"

  # Internal hostname of the broker inside the environment (not reachable from the internet).
  mqtt_host = "mosquitto.internal.${azurerm_container_app_environment.main.default_domain}"
}

# --- MQTT broker --------------------------------------------------------------

resource "azurerm_container_app" "mosquitto" {
  name                         = "mosquitto"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  secret {
    name  = "mqtt-api-password"
    value = random_password.mqtt_api.result
  }

  secret {
    name  = "mqtt-simulator-password"
    value = random_password.mqtt_simulator.result
  }

  secret {
    name  = "mqtt-server-crt"
    value = tls_locally_signed_cert.mqtt_server.cert_pem
  }

  secret {
    name  = "mqtt-server-key"
    value = tls_private_key.mqtt_server.private_key_pem
  }

  template {
    # Exactly one broker: clients and subscriptions live in its memory.
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "mosquitto"
      image  = "${local.image_prefix}-mosquitto:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "MQTT_API_PASSWORD"
        secret_name = "mqtt-api-password"
      }

      env {
        name        = "MQTT_SIMULATOR_PASSWORD"
        secret_name = "mqtt-simulator-password"
      }

      # Secrets are mounted as files named after the secret.
      env {
        name  = "TLS_CERT_FILE"
        value = "/mosquitto/certs/mqtt-server-crt"
      }

      env {
        name  = "TLS_KEY_FILE"
        value = "/mosquitto/certs/mqtt-server-key"
      }

      volume_mounts {
        name = "secrets"
        path = "/mosquitto/certs"
      }
    }

    volume {
      name         = "secrets"
      storage_type = "Secret"
    }
  }

  # Internal TCP only: reachable by the other apps, never from the internet.
  ingress {
    external_enabled = false
    transport        = "tcp"
    target_port      = 8883
    exposed_port     = 8883

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  lifecycle {
    # The CI pipeline deploys new image versions; Terraform must not undo that.
    ignore_changes = [template[0].container[0].image]
  }
}

# --- API ----------------------------------------------------------------------

resource "azurerm_container_app" "api" {
  name                         = "api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  secret {
    name  = "database-url"
    value = local.database_url
  }

  secret {
    name  = "mqtt-password"
    value = random_password.mqtt_api.result
  }

  secret {
    name  = "mqtt-ca-crt"
    value = tls_self_signed_cert.mqtt_ca.cert_pem
  }

  template {
    # One replica: each replica would subscribe and store every reading again.
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "api"
      image  = "${local.image_prefix}-api:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      env {
        name  = "MQTT_HOST"
        value = local.mqtt_host
      }

      env {
        name  = "MQTT_PORT"
        value = "8883"
      }

      env {
        name  = "MQTT_USERNAME"
        value = "api"
      }

      env {
        name        = "MQTT_PASSWORD"
        secret_name = "mqtt-password"
      }

      env {
        name  = "MQTT_CA_FILE"
        value = "/secrets/mqtt-ca-crt"
      }

      volume_mounts {
        name = "secrets"
        path = "/secrets"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 8000
        path      = "/health"
      }
    }

    volume {
      name         = "secrets"
      storage_type = "Secret"
    }
  }

  # Public HTTPS endpoint (plain HTTP is not allowed).
  ingress {
    external_enabled = true
    transport        = "http"
    target_port      = 8000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}

# --- Simulator ----------------------------------------------------------------

resource "azurerm_container_app" "simulator" {
  name                         = "simulator"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  secret {
    name  = "mqtt-password"
    value = random_password.mqtt_simulator.result
  }

  secret {
    name  = "mqtt-ca-crt"
    value = tls_self_signed_cert.mqtt_ca.cert_pem
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "simulator"
      image  = "${local.image_prefix}-simulator:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "MQTT_HOST"
        value = local.mqtt_host
      }

      env {
        name  = "MQTT_PORT"
        value = "8883"
      }

      env {
        name  = "MQTT_USERNAME"
        value = "simulator"
      }

      env {
        name        = "MQTT_PASSWORD"
        secret_name = "mqtt-password"
      }

      env {
        name  = "MQTT_CA_FILE"
        value = "/secrets/mqtt-ca-crt"
      }

      volume_mounts {
        name = "secrets"
        path = "/secrets"
      }
    }

    volume {
      name         = "secrets"
      storage_type = "Secret"
    }
  }

  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}
