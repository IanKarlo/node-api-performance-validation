import http from 'k6/http';
import { check, group } from 'k6';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
const BASE_URL_TS = __ENV.BASE_URL_TS || 'http://localhost:3000';
const BASE_URL_RS = __ENV.BASE_URL_RS || 'http://localhost:3100';
const BASE_URL_ZG = __ENV.BASE_URL_ZG || 'http://localhost:3200';

const ROUTE_DURATION_MINUTES = 4;
const REST_DURATION_MINUTES = 2;
const VUS_PER_VARIANT = 20;

const ROUTE_PHASES = [
  { name: 'risk_report_small', exec: 'runRiskReportSmall' },
  { name: 'risk_report_medium', exec: 'runRiskReportMedium' },
  { name: 'risk_report_big', exec: 'runRiskReportBig' },
  { name: 'batch_score', exec: 'runBatchScore' },
  { name: 'analytics_summary', exec: 'runAnalyticsSummary' },
];

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

function phaseStartTime(phaseIndex) {
  return `${phaseIndex * (ROUTE_DURATION_MINUTES + REST_DURATION_MINUTES)}m`;
}

function buildScenario(variant, baseUrl, phase, phaseIndex) {
  return {
    executor: 'constant-vus',
    vus: VUS_PER_VARIANT,
    duration: `${ROUTE_DURATION_MINUTES}m`,
    startTime: phaseStartTime(phaseIndex),
    gracefulStop: '30s',
    tags: { variant },
    env: { VARIANT_URL: baseUrl },
    exec: phase.exec,
  };
}

function buildScenariosForVariant(variant, baseUrl) {
  const variantScenarios = {};

  for (let phaseIndex = 0; phaseIndex < ROUTE_PHASES.length; phaseIndex += 1) {
    const phase = ROUTE_PHASES[phaseIndex];
    const scenarioName = `${variant}_${phase.name}`;
    variantScenarios[scenarioName] = buildScenario(variant, baseUrl, phase, phaseIndex);
  }

  return variantScenarios;
}

// ---------------------------------------------------------------------------
// Scenarios — endpoint-isolated phases with cooldown windows
// ---------------------------------------------------------------------------
export const options = {
  scenarios: {
    ...buildScenariosForVariant('ts', BASE_URL_TS),
    ...buildScenariosForVariant('rs', BASE_URL_RS),
    ...buildScenariosForVariant('zg', BASE_URL_ZG),
  },

  thresholds: {
    'http_req_duration{variant:ts,endpoint:risk_report_small}': ['p(95)<500'],
    'http_req_duration{variant:ts,endpoint:risk_report_medium}': ['p(95)<500'],
    'http_req_duration{variant:ts,endpoint:risk_report_big}': ['p(95)<500'],
    'http_req_duration{variant:ts,endpoint:batch_score}': ['p(95)<500'],
    'http_req_duration{variant:ts,endpoint:analytics_summary}': ['p(95)<500'],

    'http_req_duration{variant:rs,endpoint:risk_report_small}': ['p(95)<500'],
    'http_req_duration{variant:rs,endpoint:risk_report_medium}': ['p(95)<500'],
    'http_req_duration{variant:rs,endpoint:risk_report_big}': ['p(95)<500'],
    'http_req_duration{variant:rs,endpoint:batch_score}': ['p(95)<500'],
    'http_req_duration{variant:rs,endpoint:analytics_summary}': ['p(95)<500'],

    'http_req_duration{variant:zg,endpoint:risk_report_small}': ['p(95)<500'],
    'http_req_duration{variant:zg,endpoint:risk_report_medium}': ['p(95)<500'],
    'http_req_duration{variant:zg,endpoint:risk_report_big}': ['p(95)<500'],
    'http_req_duration{variant:zg,endpoint:batch_score}': ['p(95)<500'],
    'http_req_duration{variant:zg,endpoint:analytics_summary}': ['p(95)<500'],

    'http_req_failed{variant:ts,endpoint:risk_report_small}': ['rate<0.01'],
    'http_req_failed{variant:ts,endpoint:risk_report_medium}': ['rate<0.01'],
    'http_req_failed{variant:ts,endpoint:risk_report_big}': ['rate<0.01'],
    'http_req_failed{variant:ts,endpoint:batch_score}': ['rate<0.01'],
    'http_req_failed{variant:ts,endpoint:analytics_summary}': ['rate<0.01'],

    'http_req_failed{variant:rs,endpoint:risk_report_small}': ['rate<0.01'],
    'http_req_failed{variant:rs,endpoint:risk_report_medium}': ['rate<0.01'],
    'http_req_failed{variant:rs,endpoint:risk_report_big}': ['rate<0.01'],
    'http_req_failed{variant:rs,endpoint:batch_score}': ['rate<0.01'],
    'http_req_failed{variant:rs,endpoint:analytics_summary}': ['rate<0.01'],

    'http_req_failed{variant:zg,endpoint:risk_report_small}': ['rate<0.01'],
    'http_req_failed{variant:zg,endpoint:risk_report_medium}': ['rate<0.01'],
    'http_req_failed{variant:zg,endpoint:risk_report_big}': ['rate<0.01'],
    'http_req_failed{variant:zg,endpoint:batch_score}': ['rate<0.01'],
    'http_req_failed{variant:zg,endpoint:analytics_summary}': ['rate<0.01'],
  },
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
