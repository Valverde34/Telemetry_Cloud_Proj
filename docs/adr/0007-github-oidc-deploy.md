# ADR 0007: GitHub Actions deploys to Azure with OIDC

Status: accepted

## Context

The pipeline must update Azure without storing a long-lived password or service principal secret in GitHub.

## Decision

A user-assigned managed identity with a federated credential that trusts GitHub's OIDC tokens only for this repository's `production` environment. The deploy job requests a short-lived token (`id-token: write`). The identity gets `Reader` on the resource group and `Contributor` only on the three container apps.

## Consequences

- No secret to leak or rotate; tokens expire in minutes.
- Least privilege: the pipeline can deploy images but cannot change the network, the database or permissions.
- Infrastructure changes (`terraform apply`) are still run by a person. Running `terraform plan` on pull requests would be a next step.
