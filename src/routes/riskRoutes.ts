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
import { getLangModelConfig, logLangModelUsage } from '../config/lang-model';
import { recordComputation, recordBatchItems, getImplementationName } from '../metrics';

let nativeFunctions: any = null;
const config = getLangModelConfig();
if (config.useRust) {
  nativeFunctions = require('@native-rust');
} else if (config.useZig) {
  nativeFunctions = require('@native-zig');
}

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
  count: z.number().int().positive().max(10000000),
  featureConfig: z.record(z.any()).optional(),
  seed: z.number().int().optional(),
});

/**
 * POST /risk/report
 * Generate full risk report for a customer/vehicle pair
 */
router.post('/report', async (req: Request, res: Response) => {
  const implementation = getImplementationName(config.useRust, config.useZig);
  let computationStart: bigint | null = null;
  let body: RiskReportRequest | null = null;

  try {
    body = riskReportSchema.parse(req.body) as RiskReportRequest;
    computationStart = process.hrtime.bigint();

    const customer = customerService.getCustomer(body.customerId);
    const vehicle = vehicleService.getVehicle(body.vehicleId);

    let response: any;

    if (config.useRust || config.useZig) {
      logLangModelUsage('POST /risk/report');
      response = nativeFunctions.generateRiskReport(
        body.customerId,
        body.vehicleId,
        body.historySize,
        body.simulationIterations,
        body.seed || null,
        customer,
        vehicle
      );
    } else {
      logLangModelUsage('POST /risk/report');
      const events = generateHistory(
        body.customerId,
        body.vehicleId,
        body.historySize,
        body.seed
      );

      const features = deriveFeatures(events, customer, vehicle);
      const score = calculateScore(features);
      const simulation = monteCarloSimulation(
        score,
        body.simulationIterations,
        body.seed
      );

      response = {
        customerId: body.customerId,
        vehicleId: body.vehicleId,
        features,
        score,
        simulation,
      };
    }

    res.json(response);
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Validation error', details: error.errors });
    } else {
      console.error('Error generating risk report:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  } finally {
    if (body && computationStart !== null) {
      const computationSeconds = Number(process.hrtime.bigint() - computationStart) / 1e9;
      recordComputation('risk_report', implementation, computationSeconds);
    }
  }
});

/**
 * POST /risk/batch-score
 * Calculate risk scores for a batch of profiles
 */
router.post('/batch-score', async (req: Request, res: Response) => {
  const implementation = getImplementationName(config.useRust, config.useZig);
  let computationStart: bigint | null = null;
  let body: BatchScoreRequest | null = null;

  try {
    body = batchScoreSchema.parse(req.body) as BatchScoreRequest;
    computationStart = process.hrtime.bigint();

    let response: any;

    if (config.useRust || config.useZig) {
      logLangModelUsage('POST /risk/batch-score');
      const nativeStats = nativeFunctions.batchScoreAnalysis(
        body.count,
        body.seed || null
      );

      response = {
        totalProcessed: body.count,
        statistics: {
          meanScore: nativeStats.meanScore ?? nativeStats.mean_score,
          stdDev: nativeStats.stdDev ?? nativeStats.std_dev,
          min: nativeStats.min,
          max: nativeStats.max,
        },
      };
    } else {
      logLangModelUsage('POST /risk/batch-score');
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

      response = {
        totalProcessed: body.count,
        statistics,
      };
    }

    res.json(response);
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Validation error', details: error.errors });
    } else {
      console.error('Error in batch scoring:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  } finally {
    if (body && computationStart !== null) {
      const computationSeconds = Number(process.hrtime.bigint() - computationStart) / 1e9;
      recordComputation('batch_score', implementation, computationSeconds);
      recordBatchItems('batch_score', implementation, body.count);
    }
  }
});

export default router;
