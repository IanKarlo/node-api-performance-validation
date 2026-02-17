#!/usr/bin/env bash
# ============================================================
# Deploy all resources to Kubernetes
# Usage: ./k8s/deploy.sh [apply|delete]
# ============================================================
set -euo pipefail

ACTION="${1:-apply}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> ${ACTION^}ing namespace..."
kubectl "$ACTION" -f "$SCRIPT_DIR/namespace.yaml"

if [[ "$ACTION" == "apply" ]]; then
  echo "==> Deploying API variants..."
  kubectl "$ACTION" -f "$SCRIPT_DIR/app-typescript.yaml"
  kubectl "$ACTION" -f "$SCRIPT_DIR/app-rust.yaml"
  kubectl "$ACTION" -f "$SCRIPT_DIR/app-zig.yaml"

  echo "==> Deploying monitoring stack..."
  kubectl "$ACTION" -f "$SCRIPT_DIR/prometheus.yaml"
  kubectl "$ACTION" -f "$SCRIPT_DIR/grafana.yaml"

  echo "==> Deploying ingress..."
  kubectl "$ACTION" -f "$SCRIPT_DIR/ingress.yaml"

  echo ""
  echo "Deployment complete! Check status with:"
  echo "  kubectl get all -n node-api-perf"
  echo ""
  echo "Port-forward examples:"
  echo "  kubectl port-forward -n node-api-perf svc/api-typescript 3000:3000"
  echo "  kubectl port-forward -n node-api-perf svc/api-rust 3100:3100"
  echo "  kubectl port-forward -n node-api-perf svc/api-zig 3200:3200"
  echo "  kubectl port-forward -n node-api-perf svc/prometheus 9090:9090"
  echo "  kubectl port-forward -n node-api-perf svc/grafana 3001:3000"
else
  echo "==> Deleting all resources..."
  kubectl "$ACTION" -f "$SCRIPT_DIR/" --ignore-not-found
fi
