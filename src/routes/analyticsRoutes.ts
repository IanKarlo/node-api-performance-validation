import { Router, Request, Response } from 'express';
import { generateHistory } from '../computation/history';
import { calculateCustomerAnalytics } from '../computation/analytics';
import { getLangModelConfig, logLangModelUsage } from '../config/lang-model';

const router = Router();

/**
 * GET /analytics/customer/:id/summary
 * Returns analytical summary of customer history
 */
router.get('/customer/:id/summary', async (req: Request, res: Response) => {
  try {
    const customerId = req.params.id;

    if (!customerId) {
      res.status(400).json({ error: 'Customer ID is required' });
      return;
    }

    logLangModelUsage(req.path);
    const config = getLangModelConfig();
    const vehicleId = `vehicle-${customerId}`;
    const historySize = 50000;

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
        // Fallback continues below
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
  }
});

export default router;
