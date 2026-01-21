import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { RiskReportRequest, BatchScoreRequest } from '../types';
import { generateHistory } from '../computation/history';
import { deriveFeatures, generateRandomFeatureVector } from '../computation/features';
import { calculateScore, batchScore, calculateScoreStatistics } from '../computation/scoring';
import { monteCarloSimulation } from '../computation/simulation';
import { SeededRandom } from '../computation/random';
import { CustomerService } from '../services/customerService';
import { VehicleService } from '../services/vehicleService';

const router = Router();
const customerService = new CustomerService();
const vehicleService = new VehicleService();

const riskReportSchema = z.object({
  customerId: z.string().min(1),
  vehicleId: z.string().min(1),
  historySize: z.number().int().positive().max(1000000),
  simulationIterations: z.number().int().positive().max(100000000),
  seed: z.number().int().optional(),
});

const batchScoreSchema = z.object({
  count: z.number().int().positive().max(100000),
  featureConfig: z.record(z.any()).optional(),
  seed: z.number().int().optional(),
});

/**
 * POST /risk/report
 * Generate full risk report for a customer/vehicle pair
 */
router.post('/report', async (req: Request, res: Response) => {
  try {
    const body = riskReportSchema.parse(req.body) as RiskReportRequest;

    const events = generateHistory(
      body.customerId,
      body.vehicleId,
      body.historySize,
      body.seed
    );

    const customer = customerService.getCustomer(body.customerId);
    const vehicle = vehicleService.getVehicle(body.vehicleId);

    const features = deriveFeatures(events, customer, vehicle);

    const score = calculateScore(features);

    const simulation = monteCarloSimulation(
      score,
      body.simulationIterations,
      body.seed
    );

    res.json({
      customerId: body.customerId,
      vehicleId: body.vehicleId,
      features,
      score,
      simulation,
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Validation error', details: error.errors });
    } else {
      console.error('Error generating risk report:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

/**
 * POST /risk/batch-score
 * Calculate risk scores for a batch of profiles
 */
router.post('/batch-score', async (req: Request, res: Response) => {
  try {
    const body = batchScoreSchema.parse(req.body) as BatchScoreRequest;

    const featureVectors = [];
    const rng = body.seed !== undefined ? 
      new SeededRandom(body.seed) : 
      null;

    for (let i = 0; i < body.count; i++) {
      const seed = rng ? rng.nextInt(0, 1000000) : undefined;
      featureVectors.push(generateRandomFeatureVector(seed));
    }

    const scores = batchScore(featureVectors);

    const statistics = calculateScoreStatistics(scores);

    res.json({
      totalProcessed: body.count,
      statistics,
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Validation error', details: error.errors });
    } else {
      console.error('Error in batch scoring:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

export default router;
