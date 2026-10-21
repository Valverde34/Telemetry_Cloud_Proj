# Telemetry Cloud Project

Containerised IoT telemetry pipeline: simulated sensors publish over MQTT, an API
ingests and stores readings in PostgreSQL and exposes them over REST.
Built as a hands-on DevSecOps / cloud project: Docker → CI/CD → Azure + Terraform
→ monitoring.

## Architecture

```
simulator --MQTT/TLS--> mosquitto --MQTT/TLS--> api --SQL--> postgres
               [messaging network]           [backend network, internal]
```

Diagrams for local and Azure, and the CI/CD flow: [docs/architecture.md](docs/architecture.md).
Design decisions: [docs/adr](docs/adr/).

## Security

- Network segmentation: the database is on an internal network (locally) or a
  private subnet with an NSG (Azure); it has no public endpoint.
- MQTT: TLS only (no plaintext port), per-client logins, ACLs with least privilege
  (simulator: publish `sensors/#`, API: subscribe `sensors/#`).
- No secrets in git or images: generated at startup / by Terraform.
- Containers run as non-root; application code is read-only in the image.
- CI scans every image with Trivy and runs a smoke test that checks the stack
  works and that anonymous, wrong-password and plaintext MQTT clients are rejected.
- Deploys use GitHub OIDC (no stored cloud credentials) with least-privilege roles.

## Run locally

```bash
cp .env.example .env        # then change the passwords
sh scripts/gen-certs.sh      # private CA + broker certificate (in ./certs, not in git)
docker compose up --build
curl localhost:8000/health/data
curl localhost:8000/readings
```

## API

| Endpoint | Description |
|---|---|
| `GET /health` | The API process is alive (liveness probe) |
| `GET /health/data` | Readings are flowing: 503 if none in the last 2 minutes |
| `GET /readings?limit=20` | Latest readings (max 200) |

## CI/CD

`.github/workflows/ci.yml`, on every push:

1. **build-and-scan**: build the 3 images, Trivy scan
2. **terraform**: `fmt` and `validate`
3. **smoke-test**: start the stack, check data flow and broker security
4. **publish** (main): push images to ghcr.io, tagged with the commit SHA
5. **deploy** (main, once Azure is set up): update Azure Container Apps via OIDC, then health check

## Deploy to Azure

Terraform in [`infra/`](infra/): VNet, subnets and NSG, Container Apps, PostgreSQL
Flexible Server (private), Log Analytics, availability test and email alerts.
Step by step: [docs/deploy-azure.md](docs/deploy-azure.md).

## Roadmap

- [x] Docker Compose stack
- [x] CI: build + Trivy scan
- [x] MQTT authentication and ACLs
- [x] CI smoke test (end-to-end)
- [x] MQTT TLS
- [x] Push images to a registry from CI (GHCR)
- [x] Azure infrastructure with Terraform (VNet, NSG, Container Apps, PostgreSQL)
- [x] Automated deploy from the pipeline (OIDC)
- [x] Monitoring and alerting (Azure Monitor)
- [x] Architecture diagram and design decisions (ADRs)

Possible next steps: `terraform plan` on pull requests, Trivy failing the build
on HIGH/CRITICAL, Azure Container Registry with managed identity, mutual TLS for
devices, scaling with MQTT shared subscriptions.
