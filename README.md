# Telemetry Cloud Project

Containerised IoT telemetry pipeline: simulated sensors publish over MQTT, an API
ingests and stores readings in PostgreSQL and exposes them over REST.
Built as a hands-on DevSecOps / cloud project (Docker → CI/CD → Azure + Terraform).

## Architecture

```
simulator --MQTT--> mosquitto --MQTT--> api --SQL--> postgres
             [messaging network]      [backend network, internal]
```

- `messaging` network: simulator, broker, API
- `backend` network (`internal: true`): API and database only, no outside route
- Only the API port (8000) is published to the host
- Containers run as non-root users

## Run locally

```bash
cp .env.example .env    # then edit the password
docker compose up --build
curl localhost:8000/health
curl localhost:8000/readings
```

## Roadmap

- [x] Docker Compose stack
- [x] CI: build + Trivy scan
- [ ] MQTT authentication, ACLs and TLS
- [ ] Push images to a registry from CI
- [ ] Azure infrastructure with Terraform (VNet, NSGs, Container Apps/VM)
- [ ] Automated deploy from the pipeline
- [ ] Monitoring and alerting (Azure Monitor or Prometheus + Grafana)
- [ ] Architecture diagram and design decisions (ADRs)
