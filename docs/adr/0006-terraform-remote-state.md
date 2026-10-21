# ADR 0006: Terraform remote state with a bootstrap configuration

Status: accepted

## Context

Local state files get lost, cannot be shared and cannot be used from CI. The state also contains secrets (generated passwords, TLS keys).

## Decision

A small `infra/bootstrap` configuration (local state, applied once) creates a private storage account with versioning for the state, plus the CI identity. The main configuration uses the `azurerm` backend, configured through `backend.hcl` (not committed).

## Consequences

- State is stored encrypted, versioned (recoverable) and locked during operations (blob leases).
- Access to the storage account equals access to the secrets: it must stay restricted.
- The main infrastructure can be destroyed to save money while bootstrap resources stay.
