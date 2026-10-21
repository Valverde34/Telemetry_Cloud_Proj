# Paste this into infra/backend.hcl
output "backend_hcl" {
  value = <<-EOT
    resource_group_name  = "${azurerm_resource_group.bootstrap.name}"
    storage_account_name = "${azurerm_storage_account.tfstate.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    key                  = "telemetry.tfstate"
  EOT
}

# Set these as GitHub repository *variables* (not secrets: none are sensitive).
output "github_variables" {
  value = {
    AZURE_CLIENT_ID       = azurerm_user_assigned_identity.github.client_id
    AZURE_TENANT_ID       = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
  }
}
