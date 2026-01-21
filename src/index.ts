import express, { Express, Request, Response } from 'express';
import riskRoutes from './routes/riskRoutes';
import analyticsRoutes from './routes/analyticsRoutes';

const app: Express = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || 'localhost';

app.use(express.json());

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/risk', riskRoutes);
app.use('/analytics', analyticsRoutes);

app.use((err: Error, req: Request, res: Response, next: any) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
  console.log(`Health check: http://${HOST}:${PORT}/health`);
  console.log(`Risk report: POST http://${HOST}:${PORT}/risk/report`);
  console.log(`Batch score: POST http://${HOST}:${PORT}/risk/batch-score`);
  console.log(`Customer analytics: GET http://${HOST}:${PORT}/analytics/customer/:id/summary`);
});
