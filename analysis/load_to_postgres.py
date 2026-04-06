#!/usr/bin/env python3
"""
ETL script: loads Prometheus time-series + k6 experiment data into PostgreSQL.

Usage:
    # 1. Start PostgreSQL
    docker compose -f analysis/docker-compose.yml up -d

    # 2. Start Prometheus replay (uses latest export)
    ./replay/run-replay.sh up

    # 3. Run this script
    python analysis/load_to_postgres.py

    # With options:
    python analysis/load_to_postgres.py \
        --prom-url http://localhost:9092 \
        --pg-dsn "postgresql://perf:perf@localhost:5433/perf_analysis" \
        --experiments-dir docs/k6-experiments \
        --batch 20260308-144054 \
        --step 60 \
        --reset
"""

import argparse
import hashlib
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from glob import glob
from pathlib import Path

import psycopg2
import psycopg2.extras
import requests

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DEFAULT_PROM_URL = "http://localhost:9092"
DEFAULT_PG_DSN = "postgresql://perf:perf@localhost:5433/perf_analysis"
DEFAULT_EXPERIMENTS_DIR = "docs/k6-experiments"
DEFAULT_STEP = 15  # seconds

ROOT_DIR = Path(__file__).resolve().parent.parent
SCHEMA_FILE = Path(__file__).resolve().parent / "schema.sql"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_k6_metric_labels(raw_name: str):
    """Parse 'http_req_duration{variant:rs,endpoint:foo,load_scenario:bar}'
    Returns (base_name, {label_key: label_value})"""
    match = re.match(r"^([^{]+)\{([^}]+)\}$", raw_name)
    if not match:
        return raw_name, {}
    base = match.group(1)
    labels = {}
    for pair in match.group(2).split(","):
        k, _, v = pair.partition(":")
        labels[k.strip()] = v.strip()
    return base, labels


def labels_hash(metric_name: str, labels: dict) -> str:
    canonical = metric_name + "|" + "&".join(
        f"{k}={v}" for k, v in sorted(labels.items())
    )
    return hashlib.sha256(canonical.encode()).hexdigest()


# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

def connect_pg(dsn: str):
    for attempt in range(10):
        try:
            conn = psycopg2.connect(dsn)
            conn.autocommit = False
            return conn
        except psycopg2.OperationalError:
            if attempt < 9:
                print(f"  Waiting for PostgreSQL... ({attempt + 1}/10)")
                time.sleep(2)
            else:
                raise


def reset_schema(conn):
    with conn.cursor() as cur:
        cur.execute("""
            DROP TABLE IF EXISTS prom_samples CASCADE;
            DROP TABLE IF EXISTS prom_label_sets CASCADE;
            DROP TABLE IF EXISTS prom_metrics CASCADE;
            DROP TABLE IF EXISTS k6_pod_events CASCADE;
            DROP TABLE IF EXISTS k6_pod_restarts CASCADE;
            DROP TABLE IF EXISTS k6_pods CASCADE;
            DROP TABLE IF EXISTS k6_metrics CASCADE;
            DROP TABLE IF EXISTS k6_experiments CASCADE;
            DROP VIEW IF EXISTS v_k6_variant_metrics CASCADE;
            DROP VIEW IF EXISTS v_prom_during_experiment CASCADE;
        """)
    conn.commit()


def apply_schema(conn):
    sql = SCHEMA_FILE.read_text()
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()


# ---------------------------------------------------------------------------
# k6 experiment loading
# ---------------------------------------------------------------------------

def load_k6_experiments(conn, experiments_dir: str, batch: list[str] | None):
    base = ROOT_DIR / experiments_dir
    if batch:
        batches = [base / b for b in batch]
    else:
        batches = sorted(
            p for p in base.iterdir()
            if p.is_dir() and re.match(r"\d{8}-\d{6}", p.name)
        )

    total_experiments = 0
    for batch_dir in batches:
        meta_files = sorted(batch_dir.glob("*.meta.json"))
        if not meta_files:
            continue
        print(f"  Loading batch {batch_dir.name} ({len(meta_files)} experiments)...")

        for meta_path in meta_files:
            fname_base = meta_path.name.replace(".meta.json", "")
            meta = json.loads(meta_path.read_text())

            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO k6_experiments
                        (experiment_batch, scenario, variants, endpoint, repetition,
                         start_utc, end_utc, job_name, job_failed, filename_base)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (experiment_batch, filename_base) DO NOTHING
                    RETURNING id
                """, (
                    batch_dir.name,
                    meta["scenario"],
                    meta["variants"],
                    meta["endpoint"],
                    meta["repetition"],
                    meta["start_utc"],
                    meta["end_utc"],
                    meta.get("job_name"),
                    meta.get("job_failed"),
                    fname_base,
                ))
                row = cur.fetchone()
                if row is None:
                    # Already loaded
                    continue
                exp_id = row[0]

            # Load summary
            summary_path = meta_path.with_suffix("").with_suffix(".summary.json")
            if summary_path.exists():
                _load_k6_summary(conn, exp_id, summary_path)

            # Load pods
            pods_path = meta_path.with_suffix("").with_suffix(".pods.json")
            if pods_path.exists():
                _load_k6_pods(conn, exp_id, pods_path)

            total_experiments += 1

        conn.commit()

    print(f"  Loaded {total_experiments} experiments total.")


def _load_k6_summary(conn, exp_id: int, path: Path):
    data = json.loads(path.read_text())
    metrics = data.get("metrics", {})
    rows = []
    for raw_name, info in metrics.items():
        base_name, labels = parse_k6_metric_labels(raw_name)
        vals = info.get("values", {})
        thresholds = info.get("thresholds", {})
        threshold_expr = None
        threshold_ok = None
        if thresholds:
            threshold_expr = list(thresholds.keys())[0]
            threshold_ok = list(thresholds.values())[0].get("ok")

        rows.append((
            exp_id,
            base_name,
            info.get("type"),
            info.get("contains"),
            labels.get("variant"),
            labels.get("endpoint"),
            labels.get("load_scenario"),
            vals.get("avg"),
            vals.get("min"),
            vals.get("med"),
            vals.get("max"),
            vals.get("p(90)"),
            vals.get("p(95)"),
            vals.get("count"),
            vals.get("rate"),
            vals.get("passes"),
            vals.get("fails"),
            vals.get("value"),
            threshold_expr,
            threshold_ok,
        ))

    with conn.cursor() as cur:
        psycopg2.extras.execute_batch(cur, """
            INSERT INTO k6_metrics
                (experiment_id, metric_name, metric_type, contains,
                 label_variant, label_endpoint, label_scenario,
                 val_avg, val_min, val_med, val_max, val_p90, val_p95,
                 val_count, val_rate, val_passes, val_fails, val_value,
                 threshold_expr, threshold_ok)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, rows)


def _load_k6_pods(conn, exp_id: int, path: Path):
    data = json.loads(path.read_text())

    # pods_before / pods_after
    for snapshot in ("before", "after"):
        pods = data.get(f"pods_{snapshot}", [])
        rows = []
        for p in pods:
            term = p.get("last_termination") or {}
            rows.append((
                exp_id, snapshot, p["pod"], p.get("variant"),
                p.get("phase"), p.get("ready"), p.get("restarts"),
                term.get("reason"), term.get("exit_code"),
                term.get("finished_at"),
            ))
        if rows:
            with conn.cursor() as cur:
                psycopg2.extras.execute_batch(cur, """
                    INSERT INTO k6_pods
                        (experiment_id, snapshot, pod_name, variant,
                         phase, ready, restarts, term_reason, term_exit_code,
                         term_finished_at)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                """, rows)

    # restarts_during_test
    restarts = data.get("restarts_during_test", [])
    if restarts:
        rows = []
        for r in restarts:
            term = r.get("last_termination") or {}
            rows.append((
                exp_id, r["pod"], r.get("variant"),
                r.get("restarts_before"), r.get("restarts_after"),
                r.get("restarts_added"),
                term.get("reason"), term.get("exit_code"),
                term.get("finished_at"),
            ))
        with conn.cursor() as cur:
            psycopg2.extras.execute_batch(cur, """
                INSERT INTO k6_pod_restarts
                    (experiment_id, pod_name, variant,
                     restarts_before, restarts_after, restarts_added,
                     term_reason, term_exit_code, term_finished_at)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
            """, rows)

    # events
    events = data.get("events", [])
    if events:
        rows = []
        for ev in events:
            involved = ev.get("involved_object", {})
            rows.append((
                exp_id,
                involved.get("name"),
                ev.get("reason"),
                ev.get("message"),
                ev.get("type"),
                ev.get("count"),
                ev.get("first_timestamp"),
                ev.get("last_timestamp"),
            ))
        with conn.cursor() as cur:
            psycopg2.extras.execute_batch(cur, """
                INSERT INTO k6_pod_events
                    (experiment_id, pod_name, reason, message,
                     event_type, count, first_seen, last_seen)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
            """, rows)


# ---------------------------------------------------------------------------
# Prometheus extraction
# ---------------------------------------------------------------------------

def _read_tsdb_block_range(tsdb_dir: Path):
    """Read minTime/maxTime from TSDB block meta.json files on disk."""
    min_t = float("inf")
    max_t = 0
    for entry in tsdb_dir.iterdir():
        meta_path = entry / "meta.json"
        if meta_path.is_file():
            m = json.loads(meta_path.read_text())
            min_t = min(min_t, m["minTime"])
            max_t = max(max_t, m["maxTime"])
    if min_t < float("inf") and max_t > 0:
        return min_t / 1000, max_t / 1000
    return None


def get_prom_time_range(prom_url: str, tsdb_dir: Path | None = None):
    """Get the min/max timestamps from the TSDB.

    Combines block metadata on disk (if available) with the head block
    range from the Prometheus API, since /api/v1/status/tsdb only reports
    the head block and may miss older compacted blocks.
    """
    # Start with head stats from the API
    resp = requests.get(f"{prom_url}/api/v1/status/tsdb")
    resp.raise_for_status()
    data = resp.json()["data"]
    head = data.get("headStats", data)
    min_ts = int(head["minTime"]) / 1000
    max_ts = int(head["maxTime"]) / 1000

    # Extend with block metadata from disk if available
    if tsdb_dir and tsdb_dir.is_dir():
        block_range = _read_tsdb_block_range(tsdb_dir)
        if block_range:
            min_ts = min(min_ts, block_range[0])
            max_ts = max(max_ts, block_range[1])

    return min_ts, max_ts


def get_all_metric_names(prom_url: str) -> list[str]:
    resp = requests.get(f"{prom_url}/api/v1/label/__name__/values")
    resp.raise_for_status()
    return sorted(resp.json()["data"])


def load_prometheus_data(conn, prom_url: str, step: int, tsdb_dir: Path | None = None):
    print("  Querying Prometheus time range...")
    min_ts, max_ts = get_prom_time_range(prom_url, tsdb_dir)
    print(f"  TSDB range: {datetime.fromtimestamp(min_ts, tz=timezone.utc).isoformat()}"
          f" -> {datetime.fromtimestamp(max_ts, tz=timezone.utc).isoformat()}")

    metric_names = get_all_metric_names(prom_url)
    print(f"  Found {len(metric_names)} metric names")

    # Cache metric_name -> id
    metric_id_cache = {}
    label_set_cache = {}

    total_samples = 0
    for i, metric_name in enumerate(metric_names, 1):
        print(f"  [{i}/{len(metric_names)}] {metric_name}...", end="", flush=True)

        try:
            resp = requests.get(f"{prom_url}/api/v1/query_range", params={
                "query": metric_name,
                "start": min_ts,
                "end": max_ts,
                "step": f"{step}s",
            }, timeout=60)
            resp.raise_for_status()
        except Exception as e:
            print(f" ERROR: {e}")
            continue

        result = resp.json().get("data", {}).get("result", [])
        if not result:
            print(" (no data)")
            continue

        # Ensure metric row exists
        if metric_name not in metric_id_cache:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO prom_metrics (metric_name)
                    VALUES (%s)
                    ON CONFLICT (metric_name) DO NOTHING
                    RETURNING id
                """, (metric_name,))
                row = cur.fetchone()
                if row:
                    metric_id_cache[metric_name] = row[0]
                else:
                    cur.execute(
                        "SELECT id FROM prom_metrics WHERE metric_name = %s",
                        (metric_name,),
                    )
                    metric_id_cache[metric_name] = cur.fetchone()[0]

        m_id = metric_id_cache[metric_name]
        sample_rows = []

        for series in result:
            labels = {k: v for k, v in series["metric"].items() if k != "__name__"}
            lh = labels_hash(metric_name, labels)

            if lh not in label_set_cache:
                with conn.cursor() as cur:
                    cur.execute("""
                        INSERT INTO prom_label_sets (metric_id, labels_json, labels_hash)
                        VALUES (%s, %s, %s)
                        ON CONFLICT (labels_hash) DO NOTHING
                        RETURNING id
                    """, (m_id, json.dumps(labels), lh))
                    row = cur.fetchone()
                    if row:
                        label_set_cache[lh] = row[0]
                    else:
                        cur.execute(
                            "SELECT id FROM prom_label_sets WHERE labels_hash = %s",
                            (lh,),
                        )
                        label_set_cache[lh] = cur.fetchone()[0]

            ls_id = label_set_cache[lh]

            for ts_val, str_val in series["values"]:
                try:
                    val = float(str_val)
                except (ValueError, TypeError):
                    continue
                sample_rows.append((
                    ls_id,
                    datetime.fromtimestamp(ts_val, tz=timezone.utc),
                    val,
                ))

        if sample_rows:
            with conn.cursor() as cur:
                psycopg2.extras.execute_batch(cur, """
                    INSERT INTO prom_samples (label_set_id, ts, value)
                    VALUES (%s, %s, %s)
                """, sample_rows, page_size=5000)
            conn.commit()

        total_samples += len(sample_rows)
        print(f" {len(result)} series, {len(sample_rows)} samples")

        # Small delay to avoid overwhelming Prometheus
        time.sleep(0.05)

    print(f"  Total Prometheus samples loaded: {total_samples}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Load Prometheus + k6 data into PostgreSQL for analysis"
    )
    parser.add_argument(
        "--prom-url", default=DEFAULT_PROM_URL,
        help=f"Prometheus replay URL (default: {DEFAULT_PROM_URL})",
    )
    parser.add_argument(
        "--pg-dsn", default=DEFAULT_PG_DSN,
        help=f"PostgreSQL DSN (default: {DEFAULT_PG_DSN})",
    )
    parser.add_argument(
        "--experiments-dir", default=DEFAULT_EXPERIMENTS_DIR,
        help=f"k6 experiments directory (default: {DEFAULT_EXPERIMENTS_DIR})",
    )
    parser.add_argument(
        "--batch", action="append",
        help="Load only specific experiment batch(es) (e.g. --batch 20260308-144054). Can be repeated.",
    )
    parser.add_argument(
        "--step", type=int, default=DEFAULT_STEP,
        help=f"Prometheus query step in seconds (default: {DEFAULT_STEP})",
    )
    parser.add_argument(
        "--reset", action="store_true",
        help="Drop and recreate all tables before loading",
    )
    parser.add_argument(
        "--skip-prometheus", action="store_true",
        help="Skip Prometheus data loading (load only k6 data)",
    )
    parser.add_argument(
        "--skip-k6", action="store_true",
        help="Skip k6 data loading (load only Prometheus data)",
    )
    parser.add_argument(
        "--tsdb-dir",
        help="Path to TSDB data directory on disk (to read block time ranges). "
             "Auto-detected from latest export if not specified.",
    )
    args = parser.parse_args()

    print("==> Connecting to PostgreSQL...")
    conn = connect_pg(args.pg_dsn)

    if args.reset:
        print("==> Resetting schema...")
        reset_schema(conn)

    print("==> Applying schema...")
    apply_schema(conn)

    if not args.skip_k6:
        print("==> Loading k6 experiment data...")
        load_k6_experiments(conn, args.experiments_dir, args.batch)

    if not args.skip_prometheus:
        print("==> Checking Prometheus availability...")
        try:
            resp = requests.get(f"{args.prom_url}/api/v1/status/runtimeinfo", timeout=5)
            resp.raise_for_status()
            print("  Prometheus is reachable.")
        except Exception:
            print(f"  ERROR: Cannot reach Prometheus at {args.prom_url}")
            print("  Start the replay first: ./replay/run-replay.sh up")
            sys.exit(1)

        # Resolve TSDB directory for accurate time range detection
        tsdb_dir = None
        if args.tsdb_dir:
            tsdb_dir = Path(args.tsdb_dir)
        else:
            # Auto-detect from latest export
            exports_dir = ROOT_DIR / "exports" / "prometheus"
            if exports_dir.is_dir():
                candidates = sorted(exports_dir.iterdir(), reverse=True)
                for c in candidates:
                    td = c / "tsdb-data"
                    if td.is_dir():
                        tsdb_dir = td
                        print(f"  Auto-detected TSDB dir: {tsdb_dir}")
                        break

        print("==> Loading Prometheus data...")
        load_prometheus_data(conn, args.prom_url, args.step, tsdb_dir)

    conn.close()
    print("\n==> Done! Connect with:")
    print(f'  psql "{args.pg_dsn}"')
    print()
    print("Example queries:")
    print("  -- k6 p95 latency per variant/endpoint/scenario")
    print("  SELECT scenario, endpoint, label_variant, avg(val_p95)")
    print("  FROM v_k6_variant_metrics")
    print("  WHERE metric_name = 'http_req_duration'")
    print("  GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;")
    print()
    print("  -- Prometheus CPU during a specific experiment")
    print("  SELECT * FROM v_prom_during_experiment")
    print("  WHERE prom_metric = 'process_cpu_user_seconds_total'")
    print("  AND experiment_id = 1;")


if __name__ == "__main__":
    main()
