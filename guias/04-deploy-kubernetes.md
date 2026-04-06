# Deploy no Kubernetes

Faz o deploy da API (3 variantes), Prometheus e Grafana no cluster Kubernetes.

## Pre-requisitos

- `kubectl` configurado e apontando para o cluster
- Cluster Kubernetes rodando (ver [Infraestrutura Terraform](03-infraestrutura-terraform.md))

## Deploy Completo

```bash
./k8s/deploy.sh apply
```

Este script aplica, nesta ordem:

1. Namespace `node-api-perf`
2. Deployments da API: TypeScript, Rust e Zig
3. Stack de monitoramento: Prometheus e Grafana

## Verificar Status

```bash
kubectl get all -n node-api-perf
```

## Port-Forward (acesso local aos servicos do cluster)

```bash
# API TypeScript
kubectl port-forward -n node-api-perf svc/api-typescript 3000:3000

# API Rust
kubectl port-forward -n node-api-perf svc/api-rust 3100:3100

# API Zig
kubectl port-forward -n node-api-perf svc/api-zig 3200:3200

# Prometheus
kubectl port-forward -n node-api-perf svc/prometheus 9090:9090

# Grafana
kubectl port-forward -n node-api-perf svc/grafana 3001:3000
```

## Remover Tudo

```bash
./k8s/deploy.sh delete
```

## Manifests Individuais

Se precisar aplicar recursos individualmente:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/app-typescript.yaml
kubectl apply -f k8s/app-rust.yaml
kubectl apply -f k8s/app-zig.yaml
kubectl apply -f k8s/prometheus.yaml
kubectl apply -f k8s/grafana.yaml
```
