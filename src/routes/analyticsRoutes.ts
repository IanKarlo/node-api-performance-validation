import { Router, Request, Response } from 'express';
import { generateHistory } from '../computation/history';
import { calculateCustomerAnalytics } from '../computation/analytics';
import { getLangModelConfig, logLangModelUsage } from '../config/lang-model';
import { recordComputation, getImplementationName } from '../metrics';

const router = Router();

/**
 * GET /analytics/customer/:id/summary
 * Returns analytical summary of customer history
 */
router.get('/customer/:id/summary', async (req: Request, res: Response) => {
  let computationStart: bigint | null = null;
  const customerId = req.params.id;

  if (!customerId) {
    res.status(400).json({ error: 'Customer ID is required' });
    return;
  }

  const config = getLangModelConfig();
  const implementation = getImplementationName(config.useRust, config.useZig);
  const vehicleId = `vehicle-${customerId}`;
  const historySize = 50000;

  try {
    logLangModelUsage(req.path);
    computationStart = process.hrtime.bigint();

    if (config.useRust || config.useZig) {
      try {
        let analyzeCustomerHistory;
        if (config.useRust) {
          analyzeCustomerHistory = require('@native-rust').analyzeCustomerHistory;
        } else {
          analyzeCustomerHistory = require('@native-zig').analyzeCustomerHistory;
        }

        const summary = analyzeCustomerHistory(customerId, vehicleId, historySize, undefined);
        res.json({
          customerId,
          summary,
        });
        return;
      } catch (e) {
        console.error('Failed to execute native implementation, falling back to TS', e);
      }
    }

    const events = generateHistory(customerId, vehicleId, historySize);

    const summary = calculateCustomerAnalytics(customerId, events);

    res.json({
      customerId,
      summary,
    });
  } catch (error) {
    console.error('Error generating customer analytics:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    if (computationStart !== null) {
      const computationSeconds = Number(process.hrtime.bigint() - computationStart) / 1e9;
      recordComputation('customer_analytics', implementation, computationSeconds);
    }
  }
});

export default router;
