#!/usr/bin/env bash
# ============================================================
# Export Prometheus TSDB data from the cluster to local machine
# so it can be replayed with ./replay/run-replay.sh
#
# Usage:
#   ./k8s/export-prometheus.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

NAMESPACE="${NAMESPACE:-node-api-perf}"
EXPORT_BASE_DIR="${EXPORT_BASE_DIR:-$ROOT_DIR/exports/prometheus}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
EXPORT_DIR="$EXPORT_BASE_DIR/$TIMESTAMP"

echo "==> Finding Prometheus pod..."
PROM_POD="$(kubectl get pods -n "$NAMESPACE" -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

if [[ -z "$PROM_POD" ]]; then
  echo "Error: no Prometheus pod found in namespace $NAMESPACE" >&2
  exit 1
fi

echo "    Pod: $PROM_POD"

mkdir -p "$EXPORT_DIR"

echo "==> Creating TSDB snapshot on pod..."
SNAPSHOT_RESULT="$(kubectl exec -n "$NAMESPACE" "$PROM_POD" -- wget -q -O- --post-data='' http://localhost:9090/prometheus/api/v1/admin/tsdb/snapshot 2>/dev/null || true)"

if echo "$SNAPSHOT_RESULT" | grep -q '"status":"success"'; then
  SNAPSHOT_NAME="$(echo "$SNAPSHOT_RESULT" | sed 's/.*"name":"\([^"]*\)".*/\1/')"
  SNAPSHOT_PATH="/prometheus/snapshots/$SNAPSHOT_NAME"
  echo "    Snapshot: $SNAPSHOT_NAME"

  echo "==> Copying snapshot data..."
  kubectl cp "$NAMESPACE/$PROM_POD:$SNAPSHOT_PATH" "$EXPORT_DIR/tsdb-data"

  echo "==> Cleaning up snapshot on pod..."
  kubectl exec -n "$NAMESPACE" "$PROM_POD" -- rm -rf "$SNAPSHOT_PATH" 2>/dev/null || true
else
  echo "    Snapshot API not available, falling back to direct copy..."
  echo "    (This copies live TSDB — a brief scrape delay is possible)"

  echo "==> Copying TSDB data..."
  kubectl cp "$NAMESPACE/$PROM_POD:/prometheus" "$EXPORT_DIR/tsdb-data"

  rm -f "$EXPORT_DIR/tsdb-data/lock" 2>/dev/null || true
fi

# Newer Prometheus versions store data in a data/ subdirectory.
# Flatten it so tsdb-data/ contains blocks directly (what the replay expects).
if [[ -d "$EXPORT_DIR/tsdb-data/data" ]] && ls "$EXPORT_DIR/tsdb-data/data"/01* >/dev/null 2>&1; then
  echo "==> Detected data/ subdirectory, flattening..."
  mv "$EXPORT_DIR/tsdb-data/data"/* "$EXPORT_DIR/tsdb-data/" 2>/dev/null || true
  rmdir "$EXPORT_DIR/tsdb-data/data" 2>/dev/null || true
  rm -f "$EXPORT_DIR/tsdb-data/lock" 2>/dev/null || true
fi

echo "==> Saving metadata..."
echo "$PROM_POD" > "$EXPORT_DIR/source-pod.txt"
echo "$TIMESTAMP" > "$EXPORT_DIR/export-timestamp.txt"

kubectl get configmap prometheus-config -n "$NAMESPACE" -o yaml > "$EXPORT_DIR/prometheus-configmap.yaml" 2>/dev/null || true
kubectl get deployment prometheus -n "$NAMESPACE" -o yaml > "$EXPORT_DIR/prometheus-deployment.yaml" 2>/dev/null || true

TSDB_SIZE="$(du -sh "$EXPORT_DIR/tsdb-data" 2>/dev/null | cut -f1 || echo "unknown")"

echo ""
echo "Export complete!"
echo "  Path: $EXPORT_DIR"
echo "  Size: $TSDB_SIZE"
echo ""
echo "To replay locally:"
echo "  ./replay/run-replay.sh up $EXPORT_DIR/tsdb-data"
echo ""
echo "Or just run (auto-picks latest export):"
echo "  ./replay/run-replay.sh up"
