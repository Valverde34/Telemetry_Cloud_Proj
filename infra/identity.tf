# Permissions for the GitHub Actions identity (created in infra/bootstrap).
# Least privilege: it can read the resource group and update the three
# container apps (to deploy new images), nothing else.

data "azurerm_user_assigned_identity" "github" {
  name                = "id-${var.project}-github"
  resource_group_name = "rg-${var.project}-bootstrap"
}

resource "azurerm_role_assignment" "github_read_rg" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = data.azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_deploy_apps" {
  for_each = {
    mosquitto = azurerm_container_app.mosquitto.id
    api       = azurerm_container_app.api.id
    simulator = azurerm_container_app.simulator.id
  }

  scope                = each.value
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}
