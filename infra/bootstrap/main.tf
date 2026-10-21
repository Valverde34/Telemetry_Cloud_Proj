# One-time setup, applied by hand with a LOCAL state (it creates the place
# where the main configuration keeps its remote state, so it can't use it).
#
#   - Storage account + container for the main Terraform state
#   - Managed identity that GitHub Actions logs in as (OIDC, no secrets)
#
# These resources cost (almost) nothing and are meant to stay, even when the
# main infrastructure is destroyed.

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "bootstrap" {
  name     = "rg-${var.project}-bootstrap"
  location = var.location
}

# --- Remote state -----------------------------------------------------------

# Storage account names are global, so add a random suffix.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "tfstate" {
  name                            = "st${var.project}tf${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.bootstrap.name
  location                        = azurerm_resource_group.bootstrap.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  # Keep old versions of the state file, in case one gets corrupted.
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# --- Identity for GitHub Actions ---------------------------------------------

resource "azurerm_user_assigned_identity" "github" {
  name                = "id-${var.project}-github"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
}

# Trust tokens issued by GitHub, but only for jobs of this repository that run
# in the "production" environment. No password or secret is ever created.
resource "azurerm_federated_identity_credential" "github_production" {
  name                = "github-production"
  resource_group_name = azurerm_resource_group.bootstrap.name
  parent_id           = azurerm_user_assigned_identity.github.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_repo}:environment:production"
}
