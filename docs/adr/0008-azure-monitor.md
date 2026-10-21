# ADR 0008: Monitoring and alerting with Azure Monitor

Status: accepted

## Context

We need to know when the pipeline stops working, not just when a container crashes.

## Decision

- Container logs go to Log Analytics.
- An Application Insights standard availability test calls `/health/data` every 5 minutes from three European locations. The endpoint returns 503 when no reading arrived in the last 2 minutes, so one test covers simulator → broker → API → database.
- Metric alerts: API 5xx errors, database CPU and storage. All alerts email the owner through an action group.

## Consequences

- Native to Azure, nothing extra to run (vs. Prometheus + Grafana).
- `/health` (process alive, used by the liveness probe) is kept separate from `/health/data` (data flowing), so a broken simulator does not make Azure restart the API.
