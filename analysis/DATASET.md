# Performance Validation Dataset

This directory ships the raw experimental dataset used to support the paper's
analysis of a Node.js API validated against Rust, TypeScript, and Zig
back-end variants. The dataset is distributed as a compressed PostgreSQL dump
so reviewers can reproduce every query, chart, and statistic used in the
manuscript.

## Contents

| File | Purpose |
|------|---------|
| `schema.sql` | Full DDL (tables, indexes, views). Re-applied automatically when the DB container initializes. |
| `dump/perf_analysis.dump` | PostgreSQL **custom-format** dump (`pg_dump -Fc -Z 9`) of the `perf_analysis` database (~37 MB compressed, ~664 MB uncompressed). |
| `load_to_postgres.py` | ETL script that originally populated the DB from raw k6 JSON + Prometheus exports. Not needed to use the dump. |
| `docker-compose.yml` | Spins up a Postgres 16 container on port `5433` with user/password `perf` / `perf` and database `perf_analysis`. |

## Experiment overview

- **Runs captured:** 45 k6 experiments across 1 batch
  (`2026-03-22T21:47Z` to `2026-03-23T03:08Z`).
- **Scenarios:** `pico` (spike), `rampa` (ramp), `resistencia` (soak).
- **Endpoints:** `analytics_summary`, `batch_score`,
  `risk_report_small`, `risk_report_medium`, `risk_report_big`.
- **Variants under test:** `ts` (TypeScript/Node), `rs` (Rust), `zg` (Zig)
  — all three exercised in every experiment via k6 labels.
- **Observability:** ~5.77 M Prometheus samples across 47 metric names
  covering HTTP latency histograms, Node.js event-loop lag, GC duration,
  heap/RSS memory, active handles/requests, and CPU time.

## Schema (summary)

The authoritative DDL is [`schema.sql`](schema.sql). The short version:

### k6 experiment tables

- **`k6_experiments`** — one row per k6 run; keys on
  `(experiment_batch, filename_base)`. Holds scenario, endpoint, repetition,
  start/end timestamps, job status.
- **`k6_metrics`** — per-metric results from each run (trend / counter / rate
  / gauge values, including `avg`, `min`, `med`, `max`, `p90`, `p95`,
  `count`, `rate`, `passes`, `fails`, plus threshold info). Labeled by
  variant (`ts | rs | zg`), endpoint, scenario.
- **`k6_pods`** — pod inventory snapshots taken *before* and *after* each
  experiment (phase, ready, restart count, termination reason).
- **`k6_pod_restarts`** — deltas of restarts between the two snapshots per
  pod, with termination reason/exit code when available.
- **`k6_pod_events`** — Kubernetes events observed during the experiment
  (reason, message, type, counts, first/last seen).

### Prometheus time-series

- **`prom_metrics`** — distinct metric names.
- **`prom_label_sets`** — unique label combinations per metric
  (`labels_json` as `JSONB`, `labels_hash` as uniqueness key).
- **`prom_samples`** — `(label_set_id, ts, value)` long-format samples
  (~5.77 M rows).

### Convenience views

- **`v_k6_variant_metrics`** — k6 metrics joined to their experiment with
  `label_variant` non-null, ready for variant-to-variant comparison.
- **`v_prom_during_experiment`** — Prometheus samples filtered to the
  `[start_utc, end_utc]` window of each experiment, joined to metric name
  and label set.

## Restoring the dataset

### Option A — automated (Docker Compose + `pg_restore`)

```bash
# 1. Start an empty Postgres 16 instance (schema will be applied on init)
docker compose -f analysis/docker-compose.yml up -d

# 2. Restore data into the running container
docker exec -i perf-analysis-pg pg_restore \
    -U perf -d perf_analysis \
    --data-only --disable-triggers \
    < analysis/dump/perf_analysis.dump
```

`--data-only` is used because `schema.sql` has already been applied by the
container's init script. Expect the restore to take a few minutes.

### Option B — start from scratch on any Postgres ≥ 14

```bash
createdb -U perf perf_analysis
pg_restore -U perf -d perf_analysis \
    --no-owner --clean --if-exists \
    analysis/dump/perf_analysis.dump
```

## Quick sanity checks

```sql
-- 45 experiments across 3 scenarios, 5 endpoints
SELECT scenario, endpoint, COUNT(*)
FROM k6_experiments
GROUP BY 1, 2
ORDER BY 1, 2;

-- p95 HTTP latency per variant per endpoint
SELECT endpoint, label_variant, AVG(val_p95) AS avg_p95_ms
FROM v_k6_variant_metrics
WHERE metric_name = 'http_req_duration'
GROUP BY 1, 2
ORDER BY 1, 2;

-- Average event-loop lag during each experiment
SELECT experiment_id, AVG(value) AS avg_lag
FROM v_prom_during_experiment
WHERE prom_metric = 'api_nodejs_eventloop_lag_mean_seconds'
GROUP BY 1
ORDER BY 1;
```

## Provenance

The dump was generated with:

```bash
docker exec perf-analysis-pg pg_dump \
    -U perf -d perf_analysis \
    -Fc -Z 9 -f /tmp/perf_analysis.dump
```

Raw inputs (k6 JSON summaries in `docs/k6-experiments/` and Prometheus
exports replayed from `exports/`) are loaded into this schema by
[`load_to_postgres.py`](load_to_postgres.py); see
[`guias/08-analise-dados.md`](../guias/08-analise-dados.md) for the full
pipeline.
