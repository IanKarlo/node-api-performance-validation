import './config/module-alias';

import express, { Express, Request, Response } from 'express';
import riskRoutes from './routes/riskRoutes';
import analyticsRoutes from './routes/analyticsRoutes';
import { register } from './metrics';
import { metricsMiddleware } from './middleware/metricsMiddleware';

const app: Express = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || 'localhost';

app.use(express.json());
app.use(metricsMiddleware);

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/metrics', async (req: Request, res: Response) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    res.status(500).end(error);
  }
});

app.use('/risk', riskRoutes);
app.use('/analytics', analyticsRoutes);

app.use((err: Error, req: Request, res: Response, next: any) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log();
  console.log(`Server is running on port ${PORT}`);
  console.log(`Health check: http://${HOST}:${PORT}/health`);
  console.log(`Metrics: http://${HOST}:${PORT}/metrics`);
  console.log(`Risk report: POST http://${HOST}:${PORT}/risk/report`);
  console.log(`Batch score: POST http://${HOST}:${PORT}/risk/batch-score`);
  console.log(`Customer analytics: GET http://${HOST}:${PORT}/analytics/customer/:id/summary`);
});
