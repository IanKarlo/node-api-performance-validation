import { Router, Request, Response } from 'express';
import { generateHistory } from '../computation/history';
import { calculateCustomerAnalytics } from '../computation/analytics';
import { CustomerService } from '../services/customerService';
import { VehicleService } from '../services/vehicleService';

const router = Router();
const customerService = new CustomerService();
const vehicleService = new VehicleService();

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

    const customer = customerService.getCustomer(customerId);

    const historySize = 50000;
    const vehicleId = `vehicle-${customerId}`;

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
