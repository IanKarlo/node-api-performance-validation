import client from 'prom-client';

const register = new client.Registry();

register.setDefaultLabels({
  app: 'node-api-performance-validation',
});

client.collectDefaultMetrics({
  register,
  prefix: 'api_',
  gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5],
});

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'endpoint', 'status_code', 'implementation'],
  registers: [register],
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'endpoint', 'implementation'],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  registers: [register],
});

const httpErrorsTotal = new client.Counter({
  name: 'http_request_errors_total',
  help: 'Total number of HTTP request errors',
  labelNames: ['method', 'endpoint', 'error_type', 'implementation'],
  registers: [register],
});

const apiSuccessTotal = new client.Counter({
  name: 'api_success_total',
  help: 'Total number of successful API responses',
  labelNames: ['endpoint', 'implementation'],
  registers: [register],
});

const computationDuration = new client.Histogram({
  name: 'computation_duration_seconds',
  help: 'Duration of computation operations in seconds',
  labelNames: ['operation', 'implementation'],
  buckets: [0.0001, 0.0005, 0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5, 10, 30],
  registers: [register],
});

const batchItemsProcessed = new client.Counter({
  name: 'batch_items_processed_total',
  help: 'Total number of items processed in batch operations',
  labelNames: ['operation', 'implementation'],
  registers: [register],
});

export {
  register,
  httpRequestsTotal,
  httpRequestDuration,
  httpErrorsTotal,
  apiSuccessTotal,
  computationDuration,
  batchItemsProcessed,
};

export function recordRequest(
  method: string,
  endpoint: string,
  statusCode: number,
  implementation: string
): void {
  httpRequestsTotal.labels(method, endpoint, String(statusCode), implementation).inc();
}

export function recordDuration(
  method: string,
  endpoint: string,
  implementation: string,
  durationSeconds: number
): void {
  httpRequestDuration.labels(method, endpoint, implementation).observe(durationSeconds);
}

export function recordError(
  method: string,
  endpoint: string,
  errorType: string,
  implementation: string
): void {
  httpErrorsTotal.labels(method, endpoint, errorType, implementation).inc();
}

export function recordSuccess(endpoint: string, implementation: string): void {
  apiSuccessTotal.labels(endpoint, implementation).inc();
}

export function recordComputation(
  operation: string,
  implementation: string,
  durationSeconds: number
): void {
  computationDuration.labels(operation, implementation).observe(durationSeconds);
}

export function recordBatchItems(
  operation: string,
  implementation: string,
  count: number
): void {
  batchItemsProcessed.labels(operation, implementation).inc(count);
}

export function getImplementationName(useRust: boolean, useZig: boolean): string {
  if (useRust) return 'rust';
  if (useZig) return 'zig';
  return 'typescript';
}
