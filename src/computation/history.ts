import { RiskEvent } from '../types';
import { SeededRandom } from './random';

/**
 * Generate a history of risk events for a customer/vehicle pair
 */
export function generateHistory(
  customerId: string,
  vehicleId: string,
  historySize: number,
  seed?: number
): RiskEvent[] {
  const rng = new SeededRandom(seed);
  const events: RiskEvent[] = [];
  const now = Date.now();
  const oneYearAgo = now - 365 * 24 * 60 * 60 * 1000;

  const eventTypes: RiskEvent['type'][] = [
    'FINE',
    'HEAVY_USE',
    'LATE_PAYMENT',
    'ACCIDENT',
    'MAINTENANCE',
  ];

  const severities: RiskEvent['severity'][] = [
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL',
  ];

  for (let i = 0; i < historySize; i++) {
    const timestamp = new Date(
      oneYearAgo + rng.next() * (now - oneYearAgo)
    );
    const type = rng.choice(eventTypes);
    const severity = rng.choice(severities);

    let value: number | undefined;
    if (type === 'FINE' || type === 'ACCIDENT') {
      const baseValue = severity === 'CRITICAL' ? 5000 : 
                       severity === 'HIGH' ? 2000 :
                       severity === 'MEDIUM' ? 500 : 100;
      value = baseValue * (0.5 + rng.next());
    }

    events.push({
      timestamp,
      type,
      severity,
      value,
      metadata: {
        customerId,
        vehicleId,
      },
    });
  }

  events.sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());

  return events;
}
