import http from 'k6/http';
import { check, group } from 'k6';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
const BASE_URL_TS = __ENV.BASE_URL_TS || 'http://localhost:3000';
const BASE_URL_RS = __ENV.BASE_URL_RS || 'http://localhost:3100';
const BASE_URL_ZG = __ENV.BASE_URL_ZG || 'http://localhost:3200';

const ENDPOINT_EXECUTORS = {
  risk_report_small: 'runRiskReportSmall',
  risk_report_medium: 'runRiskReportMedium',
  risk_report_big: 'runRiskReportBig',
  batch_score: 'runBatchScore',
  analytics_summary: 'runAnalyticsSummary',
};

const BASE_URLS_BY_VARIANT = {
  ts: BASE_URL_TS,
  rs: BASE_URL_RS,
  zg: BASE_URL_ZG,
};

const SCENARIO_ALIASES = {
  pico: 'pico',
  peak: 'pico',
  rampa: 'rampa',
  ramp: 'rampa',
  resistencia: 'resistencia',
  endurance: 'resistencia',
  soak: 'resistencia',
};

const SCENARIO_PROFILES = {
  pico: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '10s', target: 40 },
      { duration: '2m', target: 40 },
      { duration: '10s', target: 0 },
    ],
    gracefulRampDown: '20s',
  },
  rampa: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '1m', target: 10 },
      { duration: '1m', target: 20 },
      { duration: '1m', target: 30 },
      { duration: '1m', target: 40 },
      { duration: '1m', target: 0 },
    ],
    gracefulRampDown: '30s',
  },
  resistencia: {
    executor: 'constant-vus',
    vus: 20,
    duration: '12m',
    gracefulStop: '30s',
  },
};

function parseList(value, fallbackValues) {
  if (!value || value.toLowerCase() === 'all') {
    return fallbackValues;
  }

  return value
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

function normalizeScenario(value) {
  const normalized = SCENARIO_ALIASES[(value || '').toLowerCase()];
  return normalized || 'rampa';
}

function uniqueValid(values, validValues) {
  const validSet = new Set(validValues);
  const unique = [];

  for (const value of values) {
    if (validSet.has(value) && !unique.includes(value)) {
      unique.push(value);
    }
  }

  return unique;
}

const SELECTED_SCENARIO = normalizeScenario(__ENV.LOAD_SCENARIO || __ENV.SCENARIO || 'rampa');
const SELECTED_VARIANTS = uniqueValid(
  parseList(__ENV.TEST_VARIANTS || __ENV.TEST_VARIANT || 'all', Object.keys(BASE_URLS_BY_VARIANT)),
  Object.keys(BASE_URLS_BY_VARIANT)
);
const SELECTED_ENDPOINTS = uniqueValid(
  parseList(__ENV.TEST_ENDPOINTS || __ENV.TEST_ENDPOINT || 'all', Object.keys(ENDPOINT_EXECUTORS)),
  Object.keys(ENDPOINT_EXECUTORS)
);

function jsonParams(endpoint) {
  return {
    headers: { 'Content-Type': 'application/json' },
    tags: { endpoint },
  };
}

function getParams(endpoint) {
  return {
    tags: { endpoint },
  };
}

function buildScenario(variant, endpoint, loadScenario) {
  const profile = SCENARIO_PROFILES[loadScenario];
  const baseUrl = BASE_URLS_BY_VARIANT[variant];

  return {
    ...profile,
    exec: ENDPOINT_EXECUTORS[endpoint],
    tags: {
      variant,
      endpoint,
      load_scenario: loadScenario,
    },
    env: { VARIANT_URL: baseUrl },
  };
}

function buildScenarios(variants, endpoints, loadScenario) {
  const scenarios = {};

  for (const variant of variants) {
    for (const endpoint of endpoints) {
      const scenarioName = `${variant}_${endpoint}_${loadScenario}`;
      scenarios[scenarioName] = buildScenario(variant, endpoint, loadScenario);
    }
  }

  return scenarios;
}

function buildThresholds(variants, endpoints, loadScenario) {
  const thresholds = {};

  for (const variant of variants) {
    for (const endpoint of endpoints) {
      const tags = `variant:${variant},endpoint:${endpoint},load_scenario:${loadScenario}`;
      thresholds[`http_req_duration{${tags}}`] = ['p(95)<500'];
      thresholds[`http_req_failed{${tags}}`] = ['rate<0.01'];
    }
  }

  return thresholds;
}

// ---------------------------------------------------------------------------
// Scenarios — experimental load profiles (pico, rampa, resistencia)
// ---------------------------------------------------------------------------
export const options = {
  scenarios: buildScenarios(SELECTED_VARIANTS, SELECTED_ENDPOINTS, SELECTED_SCENARIO),
  thresholds: buildThresholds(SELECTED_VARIANTS, SELECTED_ENDPOINTS, SELECTED_SCENARIO),
};

// ---------------------------------------------------------------------------
// Payloads
// ---------------------------------------------------------------------------
const RISK_REPORT_SMALL = JSON.stringify({
  customerId: 'cust-001',
  vehicleId: 'veh-001',
  historySize: 500,
  simulationIterations: 1000,
  seed: 42,
});

const RISK_REPORT_MEDIUM = JSON.stringify({
  customerId: 'cust-002',
  vehicleId: 'veh-002',
  historySize: 5000,
  simulationIterations: 10000,
  seed: 42,
});

const RISK_REPORT_BIG = JSON.stringify({
  customerId: 'cust-003',
  vehicleId: 'veh-003',
  historySize: 20000,
  simulationIterations: 50000,
  seed: 42,
});

const BATCH_SCORE = JSON.stringify({
  count: 1000,
  seed: 42,
});

// ---------------------------------------------------------------------------
// Endpoint executors — each scenario stresses a single route
// ---------------------------------------------------------------------------
export function runRiskReportSmall() {
  const base = __ENV.VARIANT_URL;

  group('POST /risk/report (small)', () => {
    const res = http.post(
      `${base}/risk/report`,
      RISK_REPORT_SMALL,
      jsonParams('risk_report_small')
    );
    check(res, {
      'risk/report small: status 200': (r) => r.status === 200,
    });
  });
}

export function runRiskReportMedium() {
  const base = __ENV.VARIANT_URL;

  group('POST /risk/report (medium)', () => {
    const res = http.post(
      `${base}/risk/report`,
      RISK_REPORT_MEDIUM,
      jsonParams('risk_report_medium')
    );
    check(res, {
      'risk/report medium: status 200': (r) => r.status === 200,
    });
  });
}

export function runRiskReportBig() {
  const base = __ENV.VARIANT_URL;

  group('POST /risk/report (big)', () => {
    const res = http.post(`${base}/risk/report`, RISK_REPORT_BIG, jsonParams('risk_report_big'));
    check(res, {
      'risk/report big: status 200': (r) => r.status === 200,
    });
  });
}

export function runBatchScore() {
  const base = __ENV.VARIANT_URL;

  group('POST /risk/batch-score', () => {
    const res = http.post(`${base}/risk/batch-score`, BATCH_SCORE, jsonParams('batch_score'));
    check(res, {
      'batch-score: status 200': (r) => r.status === 200,
    });
  });
}

export function runAnalyticsSummary() {
  const base = __ENV.VARIANT_URL;

  group('GET /analytics/customer/:id/summary', () => {
    const res = http.get(
      `${base}/analytics/customer/cust-001/summary`,
      getParams('analytics_summary')
    );
    check(res, {
      'analytics summary: status 200': (r) => r.status === 200,
    });
  });
}
