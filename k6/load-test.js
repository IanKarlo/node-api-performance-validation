import http from 'k6/http';
import { check, group } from 'k6';
import { randomSeed } from 'k6';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
const BASE_URL_TS = __ENV.BASE_URL_TS || 'http://localhost:3000';
const BASE_URL_RS = __ENV.BASE_URL_RS || 'http://localhost:3100';
const BASE_URL_ZG = __ENV.BASE_URL_ZG || 'http://localhost:3200';

const JSON_HEADERS = { headers: { 'Content-Type': 'application/json' } };

// ---------------------------------------------------------------------------
// Scenarios — each variant gets its own executor so results are tagged
// ---------------------------------------------------------------------------
export const options = {
  scenarios: {
    ts: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 20 },
        { duration: '1m', target: 20 },
        { duration: '15s', target: 0 },
      ],
      tags: { variant: 'ts' },
      env: { VARIANT_URL: BASE_URL_TS },
      exec: 'runSuite',
    },
    rs: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 20 },
        { duration: '1m', target: 20 },
        { duration: '15s', target: 0 },
      ],
      tags: { variant: 'rs' },
      env: { VARIANT_URL: BASE_URL_RS },
      exec: 'runSuite',
    },
    zg: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 20 },
        { duration: '1m', target: 20 },
        { duration: '15s', target: 0 },
      ],
      tags: { variant: 'zg' },
      env: { VARIANT_URL: BASE_URL_ZG },
      exec: 'runSuite',
    },
  },

  thresholds: {
    'http_req_duration{variant:ts}': ['p(95)<500'],
    'http_req_duration{variant:rs}': ['p(95)<500'],
    'http_req_duration{variant:zg}': ['p(95)<500'],
    'http_req_failed{variant:ts}': ['rate<0.01'],
    'http_req_failed{variant:rs}': ['rate<0.01'],
    'http_req_failed{variant:zg}': ['rate<0.01'],
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

const BATCH_SCORE = JSON.stringify({
  count: 1000,
  seed: 42,
});

// ---------------------------------------------------------------------------
// Test suite — called once per VU iteration
// ---------------------------------------------------------------------------
export function runSuite() {
  const base = __ENV.VARIANT_URL;

  group('GET /health', () => {
    const res = http.get(`${base}/health`);
    check(res, {
      'health: status 200': (r) => r.status === 200,
    });
  });

  group('GET /metrics', () => {
    const res = http.get(`${base}/metrics`);
    check(res, {
      'metrics: status 200': (r) => r.status === 200,
    });
  });

  group('POST /risk/report (small)', () => {
    const res = http.post(`${base}/risk/report`, RISK_REPORT_SMALL, JSON_HEADERS);
    check(res, {
      'risk/report small: status 200': (r) => r.status === 200,
    });
  });

  group('POST /risk/report (medium)', () => {
    const res = http.post(`${base}/risk/report`, RISK_REPORT_MEDIUM, JSON_HEADERS);
    check(res, {
      'risk/report medium: status 200': (r) => r.status === 200,
    });
  });

  group('POST /risk/batch-score', () => {
    const res = http.post(`${base}/risk/batch-score`, BATCH_SCORE, JSON_HEADERS);
    check(res, {
      'batch-score: status 200': (r) => r.status === 200,
    });
  });

  group('GET /analytics/customer/:id/summary', () => {
    const res = http.get(`${base}/analytics/customer/cust-001/summary`);
    check(res, {
      'analytics summary: status 200': (r) => r.status === 200,
    });
  });
}
