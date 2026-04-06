#!/usr/bin/env bash
# ============================================================
# Run k6 experiment suite against the cluster.
# Requires KUBECONFIG to be set if not using the default context.
#   export KUBECONFIG=~/.kube/node-api-perf.yaml
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

NAMESPACE="${NAMESPACE:-node-api-perf}"
JOB_NAME="${JOB_NAME:-k6-load-test}"
SCENARIOS="${SCENARIOS:-pico,rampa,resistencia}"
VARIANTS="${VARIANTS:-ts,rs,zg}"
ENDPOINTS="${ENDPOINTS:-risk_report_small,risk_report_medium,risk_report_big,batch_score,analytics_summary}"
REPETITIONS="${REPETITIONS:-3}"
RESULTS_DIR="${RESULTS_DIR:-$ROOT_DIR/docs/k6-experiments}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-7200}"
RESTART_DEPLOYMENTS="${RESTART_DEPLOYMENTS:-true}"
K6_SCRIPT_PATH="${K6_SCRIPT_PATH:-$ROOT_DIR/k6/load-test.js}"
CONTINUE_ON_JOB_FAILURE="${CONTINUE_ON_JOB_FAILURE:-true}"
IGNORE_THRESHOLD_FAILURE="${IGNORE_THRESHOLD_FAILURE:-true}"
JOB_TTL_SECONDS="${JOB_TTL_SECONDS:-300}"
CLEANUP_FINISHED_JOBS="${CLEANUP_FINISHED_JOBS:-true}"

TOTAL_RUNS=0
FAILED_RUNS=0

if [[ "$REPETITIONS" -lt 3 || "$REPETITIONS" -gt 5 ]]; then
  echo "REPETITIONS must be between 3 and 5 (received: $REPETITIONS)" >&2
  exit 1
fi

mkdir -p "$RESULTS_DIR"
RUN_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$RESULTS_DIR/$RUN_TIMESTAMP"
mkdir -p "$RUN_DIR"

echo "==> Results directory: $RUN_DIR"

echo "==> Refreshing k6 script ConfigMap..."
kubectl create configmap k6-test-script \
  --from-file=load-test.js="$K6_SCRIPT_PATH" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

IFS=',' read -r -a SCENARIO_ARRAY <<< "$SCENARIOS"
IFS=',' read -r -a ENDPOINT_ARRAY <<< "$ENDPOINTS"

# -----------------------------------------------------------------------
# Pod health snapshot — captures restart counts, status, and termination
# reason for each API pod. Output is a JSON array.
# Uses python3 for JSON processing (available everywhere, no jq needed).
# -----------------------------------------------------------------------
snapshot_pods() {
  kubectl get pods -n "$NAMESPACE" -l app=node-api -o json 2>/dev/null \
    | python3 -c '
import sys, json
data = json.load(sys.stdin)
result = []
for pod in data.get("items", []):
    cs = (pod.get("status", {}).get("containerStatuses") or [{}])[0]
    terminated = (cs.get("lastState", {}).get("terminated"))
    last_term = None
    if terminated:
        last_term = {
            "reason": terminated.get("reason", ""),
            "exit_code": terminated.get("exitCode", 0),
            "finished_at": terminated.get("finishedAt", "")
        }
    ready_conds = [c for c in pod.get("status", {}).get("conditions", []) if c.get("type") == "Ready"]
    result.append({
        "pod": pod["metadata"]["name"],
        "variant": pod["metadata"].get("labels", {}).get("variant", ""),
        "phase": pod.get("status", {}).get("phase", ""),
        "ready": ready_conds[0].get("status") == "True" if ready_conds else False,
        "restarts": cs.get("restartCount", 0),
        "last_termination": last_term
    })
json.dump(result, sys.stdout)
' 2>/dev/null || echo '[]'
}

# -----------------------------------------------------------------------
# Collect Kubernetes events for API pods within a time window
# -----------------------------------------------------------------------
collect_pod_events() {
  local since="$1"
  kubectl get events -n "$NAMESPACE" \
    --field-selector "involvedObject.kind=Pod" \
    --sort-by='.lastTimestamp' \
    -o json 2>/dev/null \
    | python3 -c '
import sys, json
since = sys.argv[1]
data = json.load(sys.stdin)
result = []
for ev in data.get("items", []):
    pod_name = ev.get("involvedObject", {}).get("name", "")
    if not pod_name.startswith("api-"):
        continue
    last_seen = ev.get("lastTimestamp") or ev.get("eventTime") or ""
    first_seen = ev.get("firstTimestamp") or ev.get("eventTime") or ""
    if last_seen < since and first_seen < since:
        continue
    result.append({
        "pod": pod_name,
        "reason": ev.get("reason", ""),
        "message": ev.get("message", ""),
        "type": ev.get("type", ""),
        "count": ev.get("count", 0),
        "first_seen": first_seen,
        "last_seen": last_seen
    })
json.dump(result, sys.stdout)
' "$since" 2>/dev/null || echo '[]'
}

restart_api_deployments() {
  if [[ "$RESTART_DEPLOYMENTS" != "true" ]]; then
    return 0
  fi

  echo "==> Restarting API deployments..."
  kubectl rollout restart deployment/api-typescript -n "$NAMESPACE"
  kubectl rollout restart deployment/api-rust -n "$NAMESPACE"
  kubectl rollout restart deployment/api-zig -n "$NAMESPACE"

  kubectl rollout status deployment/api-typescript -n "$NAMESPACE" --timeout=600s
  kubectl rollout status deployment/api-rust -n "$NAMESPACE" --timeout=600s
  kubectl rollout status deployment/api-zig -n "$NAMESPACE" --timeout=600s
}

run_one() {
  local scenario="$1"
  local endpoint="$2"
  local repetition="$3"
  local run_job_name
  local job_failed="false"

  local start_utc
  local end_utc

  echo ""
  echo "=== Running: scenario=$scenario variants=$VARIANTS endpoint=$endpoint repetition=$repetition ==="

  restart_api_deployments

  start_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local pods_before
  pods_before="$(snapshot_pods)"

  run_job_name="${JOB_NAME}-${scenario}-${endpoint}-rep${repetition}-$(date +%s)"
  run_job_name="$(echo "$run_job_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]/-/g; s/--*/-/g; s/^[^a-z0-9]*//; s/[^a-z0-9]*$//')"
  run_job_name="${run_job_name:0:63}"

  kubectl delete job "$run_job_name" -n "$NAMESPACE" --ignore-not-found=true >/dev/null 2>&1 || true

  cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${run_job_name}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/part-of: node-api-performance-validation
    app.kubernetes.io/component: load-test
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: ${JOB_TTL_SECONDS}
  template:
    metadata:
      labels:
        app: k6-load-test
    spec:
      restartPolicy: Never
      containers:
        - name: k6
          image: grafana/k6:latest
          command:
            - sh
            - -c
            - |
              set -e
              exit_code=0
              k6 run /scripts/load-test.js || exit_code=\$?
              printf "__K6_SUMMARY_JSON_START__\n"
              cat /results/summary.json || true
              printf "\n__K6_SUMMARY_JSON_END__\n"
              if [ "\$exit_code" -ne 0 ] && [ "${IGNORE_THRESHOLD_FAILURE}" = "true" ]; then
                echo "Ignoring k6 non-zero exit code due to IGNORE_THRESHOLD_FAILURE=true"
                exit_code=0
              fi
              exit "\$exit_code"
          env:
            - name: BASE_URL_TS
              value: 'http://api-typescript.node-api-perf.svc.cluster.local:3000'
            - name: BASE_URL_RS
              value: 'http://api-rust.node-api-perf.svc.cluster.local:3100'
            - name: BASE_URL_ZG
              value: 'http://api-zig.node-api-perf.svc.cluster.local:3200'
            - name: LOAD_SCENARIO
              value: '${scenario}'
            - name: TEST_VARIANTS
              value: '${VARIANTS}'
            - name: TEST_ENDPOINTS
              value: '${endpoint}'
            - name: K6_SUMMARY_PATH
              value: '/results/summary.json'
          volumeMounts:
            - name: k6-scripts
              mountPath: /scripts
              readOnly: true
            - name: k6-results
              mountPath: /results
          resources:
            requests:
              cpu: 500m
              memory: 256Mi
            limits:
              cpu: '1'
              memory: 512Mi
      volumes:
        - name: k6-scripts
          configMap:
            name: k6-test-script
        - name: k6-results
          emptyDir: {}
EOF

  if ! kubectl wait --for=condition=complete "job/$run_job_name" -n "$NAMESPACE" --timeout="${TIMEOUT_SECONDS}s"; then
    if kubectl wait --for=condition=failed "job/$run_job_name" -n "$NAMESPACE" --timeout=10s >/dev/null 2>&1; then
      job_failed="true"
      echo "Warning: job $run_job_name finished with Failed condition (likely k6 thresholds exceeded)."
    else
      echo "Error: job $run_job_name did not reach Complete or Failed condition within timeout." >&2
      return 1
    fi
  fi

  local file_prefix="$RUN_DIR/${scenario}__variants-${VARIANTS//,/+}__${endpoint}__rep${repetition}"
  local log_file="${file_prefix}.log"
  local summary_file="${file_prefix}.summary.json"

  kubectl logs "job/$run_job_name" -n "$NAMESPACE" > "$log_file"
  echo "Saved logs: $log_file"

  if awk '/__K6_SUMMARY_JSON_START__/{flag=1;next}/__K6_SUMMARY_JSON_END__/{flag=0}flag' "$log_file" > "$summary_file" && [[ -s "$summary_file" ]]; then
    echo "Saved summary: $summary_file"
  else
    rm -f "$summary_file"
    echo "Warning: failed to extract summary.json from job logs ($run_job_name)" >&2
  fi

  end_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local pods_after
  pods_after="$(snapshot_pods)"
  local pod_events
  pod_events="$(collect_pod_events "$start_utc")"

  local pods_file="${file_prefix}.pods.json"
  python3 -c '
import json, sys
before = json.loads(sys.argv[1])
after = json.loads(sys.argv[2])
events = json.loads(sys.argv[3])
start = sys.argv[4]
end = sys.argv[5]

before_map = {p["pod"]: p for p in before}
restarts = []
for a in after:
    b = before_map.get(a["pod"])
    if b and a["restarts"] > b["restarts"]:
        restarts.append({
            "pod": a["pod"],
            "variant": a["variant"],
            "restarts_before": b["restarts"],
            "restarts_after": a["restarts"],
            "restarts_added": a["restarts"] - b["restarts"],
            "last_termination": a["last_termination"]
        })

json.dump({
    "test_window": {"start": start, "end": end},
    "pods_before": before,
    "pods_after": after,
    "restarts_during_test": restarts,
    "events": events
}, sys.stdout, indent=2)
' "$pods_before" "$pods_after" "$pod_events" "$start_utc" "$end_utc" > "$pods_file" 2>/dev/null || {
    cat > "$pods_file" <<PODEOF
{
  "test_window": { "start": "${start_utc}", "end": "${end_utc}" },
  "pods_before": ${pods_before},
  "pods_after": ${pods_after},
  "events": ${pod_events}
}
PODEOF
  }
  echo "Saved pod info: $pods_file"

  local meta_file="${file_prefix}.meta.json"
  cat > "$meta_file" <<METAEOF
{
  "scenario": "${scenario}",
  "variants": "${VARIANTS}",
  "endpoint": "${endpoint}",
  "repetition": ${repetition},
  "start_utc": "${start_utc}",
  "end_utc": "${end_utc}",
  "job_name": "${run_job_name}",
  "job_failed": ${job_failed}
}
METAEOF
  echo "Saved metadata: $meta_file"

  if [[ "$CLEANUP_FINISHED_JOBS" == "true" ]]; then
    kubectl delete job "$run_job_name" -n "$NAMESPACE" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
  fi

  TOTAL_RUNS=$((TOTAL_RUNS + 1))
  if [[ "$job_failed" == "true" ]]; then
    FAILED_RUNS=$((FAILED_RUNS + 1))
    if [[ "$CONTINUE_ON_JOB_FAILURE" != "true" ]]; then
      echo "Stopping because CONTINUE_ON_JOB_FAILURE=false and job failed." >&2
      return 1
    fi
  fi
}

for scenario in "${SCENARIO_ARRAY[@]}"; do
  for endpoint in "${ENDPOINT_ARRAY[@]}"; do
    for repetition in $(seq 1 "$REPETITIONS"); do
      run_one "$scenario" "$endpoint" "$repetition"
    done
  done
done

echo ""
echo "All experiment runs completed."
echo "Output: $RUN_DIR"
echo "Runs: $TOTAL_RUNS | Failed jobs: $FAILED_RUNS"

if [[ "$FAILED_RUNS" -gt 0 ]]; then
  echo "One or more k6 jobs failed (usually due to threshold checks)." >&2
  exit 1
fi
