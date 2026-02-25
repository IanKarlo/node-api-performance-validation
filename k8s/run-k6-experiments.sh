#!/usr/bin/env bash
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

  echo ""
  echo "=== Running: scenario=$scenario variants=$VARIANTS endpoint=$endpoint repetition=$repetition ==="

  restart_api_deployments

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
              k6 run --summary-export=/results/summary.json /scripts/load-test.js || exit_code=\$?
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
