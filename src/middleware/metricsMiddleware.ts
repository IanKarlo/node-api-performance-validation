import { Request, Response, NextFunction } from 'express';
import {
  recordRequest,
  recordDuration,
  recordError,
  recordTransportError,
  recordSuccess,
  getImplementationName,
} from '../metrics';
import { getLangModelConfig } from '../config/lang-model';

export function metricsMiddleware(req: Request, res: Response, next: NextFunction): void {
  if (req.path === '/metrics') {
    next();
    return;
  }

  const startTime = process.hrtime.bigint();
  const config = getLangModelConfig();
  const implementation = getImplementationName(config.useRust, config.useZig);
  const normalizedEndpoint = normalizeEndpoint(req.path);
  let requestFinalized = false;

  res.on('finish', () => {
    requestFinalized = true;

    const endTime = process.hrtime.bigint();
    const durationSeconds = Number(endTime - startTime) / 1e9;

    recordRequest(req.method, normalizedEndpoint, res.statusCode, implementation);
    recordDuration(req.method, normalizedEndpoint, implementation, durationSeconds);

    if (res.statusCode >= 200 && res.statusCode < 400) {
      recordSuccess(normalizedEndpoint, implementation);
    } else if (res.statusCode >= 400) {
      const errorType = res.statusCode >= 500 ? 'server_error' : 'client_error';
      recordError(req.method, normalizedEndpoint, errorType, implementation);
    }
  });

  res.on('close', () => {
    if (requestFinalized) {
      return;
    }

    requestFinalized = true;

    const errorType = req.aborted ? 'request_aborted' : 'connection_closed';
    recordTransportError(req.method, normalizedEndpoint, errorType, implementation);
  });

  next();
}

function normalizeEndpoint(path: string): string {
  return path
    .replace(/\/customer\/[^/]+\//, '/customer/:id/')
    .replace(/\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, '/:uuid');
}
