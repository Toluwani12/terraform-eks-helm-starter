# Terraform + Helm + GitHub Actions

A small repo that:

- Provisions **ECR** (via a reusable Terraform module) and **EKS** (via the official community module).
- Ships a **Helm chart** for a microservice with a configurable PodDisruptionBudget, ResourceQuota, and a dynamic `image.repository`.
- Validates everything in **GitHub Actions** with a synthetic deployment (`helm install --dry-run --debug`).

## Layout

```
terraform/
  main.tf                       # root config: provider, ECR, VPC, EKS
  modules/ecr/
    main.tf                     # the reusable ECR module
    variables.tf                # input: name
    outputs.tf                  # output: repository_url
helm/microservice/
  Chart.yaml
  values.yaml                   # all configurable knobs
  templates/
    deployment.yaml             # runs the container
    service.yaml                # exposes it inside the cluster
    pdb.yaml                    # PodDisruptionBudget (toggleable)
    resourcequota.yaml          # namespace ResourceQuota (toggleable)
app/
  app.py                        # tiny "hello world" HTTP server
  Dockerfile
.github/workflows/main.yml      # the pipeline
```

## What the pipeline does

Three jobs run in order:

1. **terraform** — `fmt -check` → `init` → `validate` → `plan`. Runs with fake AWS credentials; the AWS provider has `skip_*` flags and `create_eks = false` by default, so the plan succeeds offline.
2. **docker** — builds `app/Dockerfile` and pushes the image to **GHCR** (`ghcr.io/<owner>/<repo>-microservice:sha-<commit>`).
3. **helm** — spins up a throwaway `kind` cluster, runs `helm lint`, then `helm install --dry-run --debug` while injecting the image URL from job 2.

## Running locally

```bash
# Terraform
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform plan

# Docker
docker build -t microservice:dev ./app

# Helm
helm lint helm/microservice
helm install microservice helm/microservice \
  --dry-run --debug \
  --set image.repository=microservice \
  --set image.tag=dev
```

## Real deployment

To actually create the EKS cluster + ECR:

```bash
cd terraform
terraform init
terraform apply -var "create_eks=true"
```

(Requires real AWS credentials in your shell — `aws configure` or env vars.)

## Helm values you'll likely change

| Key | What it does |
|---|---|
| `image.repository` | The Docker image URL (overridden by CI with `--set`). |
| `image.tag` | The image tag (overridden by CI with `--set`). |
| `replicaCount` | Number of pods. |
| `resources.requests` / `resources.limits` | Per-pod CPU/memory. |
| `podDisruptionBudget.enabled` | Turn the PDB on/off. |
| `podDisruptionBudget.minAvailable` | Minimum pods kept alive during voluntary disruptions. |
| `resourceQuota.enabled` | Turn the namespace ResourceQuota on/off. |
| `resourceQuota.hard` | The actual quota limits, passed straight to Kubernetes. |
