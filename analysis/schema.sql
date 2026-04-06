-- Performance Analysis Schema
-- Stores k6 experiment results + Prometheus time-series for correlation

BEGIN;

-- ============================================================
-- k6 experiment data
-- ============================================================

CREATE TABLE IF NOT EXISTS k6_experiments (
    id              SERIAL PRIMARY KEY,
    experiment_batch TEXT NOT NULL,        -- directory name, e.g. "20260308-144054"
    scenario        TEXT NOT NULL,         -- pico | rampa | resistencia
    variants        TEXT NOT NULL,         -- "ts,rs,zg"
    endpoint        TEXT NOT NULL,         -- risk_report_small, batch_score, etc.
    repetition      INT NOT NULL,
    start_utc       TIMESTAMPTZ NOT NULL,
    end_utc         TIMESTAMPTZ NOT NULL,
    job_name        TEXT,
    job_failed      BOOLEAN,
    filename_base   TEXT NOT NULL,
    UNIQUE (experiment_batch, filename_base)
);

CREATE INDEX IF NOT EXISTS idx_k6_experiments_time
    ON k6_experiments (start_utc, end_utc);

CREATE TABLE IF NOT EXISTS k6_metrics (
    id              SERIAL PRIMARY KEY,
    experiment_id   INT NOT NULL REFERENCES k6_experiments(id) ON DELETE CASCADE,
    metric_name     TEXT NOT NULL,         -- e.g. "http_req_duration"
    metric_type     TEXT,                  -- trend | counter | rate | gauge
    contains        TEXT,                  -- time | default | data
    label_variant   TEXT,                  -- ts | rs | zg (NULL for global)
    label_endpoint  TEXT,
    label_scenario  TEXT,
    -- trend values
    val_avg         DOUBLE PRECISION,
    val_min         DOUBLE PRECISION,
    val_med         DOUBLE PRECISION,
    val_max         DOUBLE PRECISION,
    val_p90         DOUBLE PRECISION,
    val_p95         DOUBLE PRECISION,
    -- counter values
    val_count       DOUBLE PRECISION,
    val_rate        DOUBLE PRECISION,
    -- rate values
    val_passes      DOUBLE PRECISION,
    val_fails       DOUBLE PRECISION,
    -- gauge values
    val_value       DOUBLE PRECISION,
    -- threshold
    threshold_expr  TEXT,
    threshold_ok    BOOLEAN
);

CREATE INDEX IF NOT EXISTS idx_k6_metrics_experiment
    ON k6_metrics (experiment_id);
CREATE INDEX IF NOT EXISTS idx_k6_metrics_variant
    ON k6_metrics (label_variant, label_endpoint, label_scenario);

CREATE TABLE IF NOT EXISTS k6_pods (
    id              SERIAL PRIMARY KEY,
    experiment_id   INT NOT NULL REFERENCES k6_experiments(id) ON DELETE CASCADE,
    snapshot        TEXT NOT NULL,         -- "before" | "after"
    pod_name        TEXT NOT NULL,
    variant         TEXT,                  -- rust | typescript | zig
    phase           TEXT,
    ready           BOOLEAN,
    restarts        INT,
    term_reason     TEXT,
    term_exit_code  INT,
    term_finished_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS k6_pod_restarts (
    id              SERIAL PRIMARY KEY,
    experiment_id   INT NOT NULL REFERENCES k6_experiments(id) ON DELETE CASCADE,
    pod_name        TEXT NOT NULL,
    variant         TEXT,
    restarts_before INT,
    restarts_after  INT,
    restarts_added  INT,
    term_reason     TEXT,
    term_exit_code  INT,
    term_finished_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS k6_pod_events (
    id              SERIAL PRIMARY KEY,
    experiment_id   INT NOT NULL REFERENCES k6_experiments(id) ON DELETE CASCADE,
    pod_name        TEXT,
    reason          TEXT,
    message         TEXT,
    event_type      TEXT,
    count           INT,
    first_seen      TIMESTAMPTZ,
    last_seen       TIMESTAMPTZ
);

-- ============================================================
-- Prometheus time-series data
-- ============================================================

CREATE TABLE IF NOT EXISTS prom_metrics (
    id              SERIAL PRIMARY KEY,
    metric_name     TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS prom_label_sets (
    id              SERIAL PRIMARY KEY,
    metric_id       INT NOT NULL REFERENCES prom_metrics(id) ON DELETE CASCADE,
    labels_json     JSONB NOT NULL,
    labels_hash     TEXT NOT NULL UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_prom_labels_metric
    ON prom_label_sets (metric_id);
CREATE INDEX IF NOT EXISTS idx_prom_labels_json
    ON prom_label_sets USING GIN (labels_json);

CREATE TABLE IF NOT EXISTS prom_samples (
    id              BIGSERIAL PRIMARY KEY,
    label_set_id    INT NOT NULL REFERENCES prom_label_sets(id) ON DELETE CASCADE,
    ts              TIMESTAMPTZ NOT NULL,
    value           DOUBLE PRECISION NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_prom_samples_lookup
    ON prom_samples (label_set_id, ts);

-- ============================================================
-- Convenience views for correlation
-- ============================================================

CREATE OR REPLACE VIEW v_k6_variant_metrics AS
SELECT
    e.id AS experiment_id,
    e.experiment_batch,
    e.scenario,
    e.endpoint,
    e.repetition,
    e.start_utc,
    e.end_utc,
    e.job_failed,
    m.metric_name,
    m.label_variant,
    m.val_avg,
    m.val_min,
    m.val_med,
    m.val_max,
    m.val_p90,
    m.val_p95,
    m.val_rate,
    m.val_count,
    m.val_passes,
    m.val_fails,
    m.threshold_ok
FROM k6_experiments e
JOIN k6_metrics m ON m.experiment_id = e.id
WHERE m.label_variant IS NOT NULL;

CREATE OR REPLACE VIEW v_prom_during_experiment AS
SELECT
    e.id AS experiment_id,
    e.experiment_batch,
    e.scenario,
    e.endpoint,
    e.repetition,
    pm.metric_name AS prom_metric,
    pl.labels_json,
    ps.ts,
    ps.value
FROM k6_experiments e
JOIN prom_samples ps ON ps.ts BETWEEN e.start_utc AND e.end_utc
JOIN prom_label_sets pl ON pl.id = ps.label_set_id
JOIN prom_metrics pm ON pm.id = pl.metric_id;

COMMIT;
