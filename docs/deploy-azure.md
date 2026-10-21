# Deploying to Azure

One-time setup, then every push to `main` deploys automatically.

> **Cost:** the always-on PostgreSQL server and three container apps cost in the
> order of tens of euros per month. Check the
> [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/) and
> run `terraform destroy` in `infra/` when you are not using it (step 8).

## Prerequisites

- An Azure subscription where you are **Owner** (Terraform creates role assignments).
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) and Terraform >= 1.5.
- Log in: `az login`, then `az account show` to check the subscription.

## 1. Publish the images

Push to `main` and wait for the **CI/CD** workflow to go green. It publishes
`telemetry-api`, `telemetry-simulator` and `telemetry-mosquitto` to ghcr.io.

Then make the three packages **public** (Azure pulls them without credentials):
GitHub → your profile → **Packages** → each package → **Package settings** →
**Change visibility** → Public.

## 2. Bootstrap (once): state storage + CI identity

```bash
cd infra/bootstrap
terraform init
terraform apply
terraform output -raw backend_hcl > ../backend.hcl
terraform output github_variables     # needed in step 5
```

## 3. Configure the main infrastructure

```bash
cd ..                                  # infra/
cp terraform.tfvars.example terraform.tfvars   # set alert_email
rm -f terraform.tfstate terraform.tfstate.backup   # old local state (empty)
terraform init -reconfigure -backend-config=backend.hcl
```

## 4. Create everything

```bash
terraform plan      # read it: what will be created?
terraform apply     # ~10-15 minutes (PostgreSQL is the slow one)
```

Test it:

```bash
API=$(terraform output -raw api_url)
curl "$API/health/data"
curl "$API/readings"
```

Confirm the email Azure sends to subscribe you to the alert group.

## 5. Enable automatic deploys

GitHub → repository → **Settings → Secrets and variables → Actions → Variables**
→ add four repository variables:

| Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | from `github_variables` (step 2) |
| `AZURE_TENANT_ID` | from `github_variables` |
| `AZURE_SUBSCRIPTION_ID` | from `github_variables` |
| `AZURE_RESOURCE_GROUP` | `terraform output -raw resource_group_name` (`rg-telemetry-tf`) |

They are variables, not secrets: none of them is sensitive (OIDC needs no password).

Optional: **Settings → Environments → production** → add yourself as required
reviewer, so every deploy waits for your approval.

## 6. Deploy

Push any commit to `main`. After `publish`, the `deploy` job logs in to Azure,
updates the three container apps to the images of that commit and waits until
`/health/data` answers 200.

## 7. Useful commands

```bash
az containerapp logs show -g rg-telemetry-tf -n api --follow     # live logs
az containerapp revision list -g rg-telemetry-tf -n api -o table # deploy history
```

## 8. Stop paying

```bash
cd infra && terraform destroy
```

The bootstrap resources (state storage, identity) cost almost nothing and can stay.
A later `terraform apply` recreates everything; the deploy job then works again.

## Troubleshooting

- **`MissingSubscriptionRegistration`**: register the providers once:
  `az provider register --namespace Microsoft.App` (same for `Microsoft.DBforPostgreSQL`,
  `Microsoft.OperationalInsights`, `Microsoft.Insights`).
- **PostgreSQL "location is restricted"**: some regions limit new subscriptions;
  set `location` in `terraform.tfvars` (e.g. `westeurope`) and apply again.
- **Container app can't pull the image**: check the packages are public (step 1).
- **API/simulator logs show the broker hostname can't be resolved**: set
  `mqtt_host = "mosquitto"` in `infra/container_apps.tf` (`locals`) and apply again;
  the TLS certificate is valid for both names.
- **Deploy job: `AADSTS70021` / no matching federated identity**: the job must run
  in the `production` environment and `github_repo` in bootstrap must match the
  repository name exactly (case-sensitive).
