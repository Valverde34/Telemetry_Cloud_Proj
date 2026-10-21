# ADR 0004: Azure Container Apps to run the containers

Status: accepted

## Context

Options considered: a VM running Docker Compose, Azure Kubernetes Service (AKS), Azure Container Apps.

## Decision

Azure Container Apps (Consumption workload profile) in a custom VNet (`snet-app`). The broker uses internal TCP ingress, the API public HTTPS ingress, the simulator no ingress. One replica each.

## Consequences

- No servers to patch and no SSH port open, unlike a VM; far simpler and cheaper than AKS for three containers.
- VNet integration lets the apps reach the private PostgreSQL server.
- Single replicas: the broker keeps state in memory, and multiple API replicas would each store every reading. Scaling out would need MQTT shared subscriptions (or a queue) and an HA broker.
- Image updates are done by CI (`az containerapp update`); Terraform ignores image changes to avoid fighting the pipeline.
