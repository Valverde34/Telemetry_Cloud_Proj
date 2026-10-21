# ADR 0005: PostgreSQL Flexible Server with private access

Status: accepted

## Context

The database needs to be managed (backups, patching) and never exposed to the internet.

## Decision

Azure Database for PostgreSQL Flexible Server, burstable B1ms, in a delegated subnet (`snet-data`) with a private DNS zone and public access disabled. The subnet NSG allows inbound 5432 only from `snet-app`. Connections use TLS (`sslmode=require`).

## Consequences

- Defence in depth: no public endpoint, subnet isolation and NSG rules.
- Automatic backups (7 days). No high availability, to keep cost low; zone-redundant HA is a setting away for production.
