output "api_url" {
  description = "Public HTTPS URL of the API."
  value       = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "resource_group_name" {
  description = "Set this as the AZURE_RESOURCE_GROUP variable in GitHub."
  value       = azurerm_resource_group.main.name
}
