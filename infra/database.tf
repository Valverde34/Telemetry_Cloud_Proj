# Managed PostgreSQL with private access only: it lives inside snet-data, has
# no public endpoint, and is resolved through a private DNS zone.

resource "random_password" "db" {
  length  = 32
  special = false # keeps the connection URL free of characters that need escaping
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.project}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "postgres-vnet-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "psql-${var.project}-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "16"
  sku_name                      = "B_Standard_B1ms" # smallest (burstable) size
  storage_mb                    = 32768
  backup_retention_days         = 7
  delegated_subnet_id           = azurerm_subnet.data.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
  administrator_login           = "telemetry"
  administrator_password        = random_password.db.result

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]

  lifecycle {
    # Azure picks an availability zone; don't try to change it afterwards.
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "telemetry" {
  name      = "telemetry"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

locals {
  # TLS to the database is enforced (sslmode=require).
  database_url = "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}:${random_password.db.result}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.telemetry.name}?sslmode=require"
}
