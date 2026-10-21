# ADR 0001: Docker Compose with segmented networks

Status: accepted

## Context

The project needs a reproducible local environment with four services (simulator, broker, API, database) that mirrors how they will be isolated in the cloud.

## Decision

- Run everything with Docker Compose, one container per service.
- Two networks: `messaging` (simulator, broker, API) and `backend` (API, DB) marked `internal: true`.
- Only the API port is published to the host. Application containers run as non-root users and their code is read-only inside the image.

## Consequences

- The database has no route to or from the outside, even locally; the API is the only bridge.
- The same network split is reproduced in Azure with subnets and an NSG.
- The broker image starts as root (the official image's entrypoint) and drops to the `mosquitto` user before serving traffic.
