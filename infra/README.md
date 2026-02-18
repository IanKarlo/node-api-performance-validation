# Terraform Infrastructure (DigitalOcean)

This Terraform stack is **infra-only** and provisions:

- VPC
- DOKS (DigitalOcean Kubernetes) cluster

Kubernetes workloads are managed separately from this folder and remain the source of truth in [k8s](../k8s).

## Prerequisites

- Terraform >= 1.6
- DigitalOcean account + API token
- `kubectl`
- `doctl` (recommended for kubeconfig setup)

## Usage

1. Copy vars and edit:
   - `cp terraform.tfvars.example terraform.tfvars`
2. Set token:
   - `export TF_VAR_do_token="dop_v1_xxx"`
3. Initialize/apply:
   - `terraform init`
   - `terraform plan`
   - `terraform apply`
4. Configure kubeconfig:
   - `doctl kubernetes cluster kubeconfig save $(terraform output -raw cluster_name)`
5. Deploy workloads from `k8s`:
   - `kubectl apply -f ../k8s/namespace.yaml`
   - `kubectl apply -f ../k8s/app-typescript.yaml -f ../k8s/app-rust.yaml -f ../k8s/app-zig.yaml`
   - `kubectl apply -f ../k8s/prometheus.yaml -f ../k8s/grafana.yaml -f ../k8s/ingress.yaml`

## Notes

- Default node count is `2` (you can set `3` if needed).
- Terraform no longer creates Kubernetes Deployments/Services to avoid duplication with the `k8s` manifests.
