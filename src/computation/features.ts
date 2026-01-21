import { RiskEvent, FeatureVector, Customer, Vehicle } from '../types';
import { SeededRandom } from './random';

/**
 * Derive feature vector from event history
 */
export function deriveFeatures(
  events: RiskEvent[],
  customer: Customer,
  vehicle: Vehicle
): FeatureVector {
  let severeFines = 0;
  let mediumFines = 0;
  let totalKm = 0;
  let latePayments = 0;
  let accidents = 0;
  let maintenanceCount = 0;
  let heavyUseCount = 0;

  for (const event of events) {
    switch (event.type) {
      case 'FINE':
        if (event.severity === 'HIGH' || event.severity === 'CRITICAL') {
          severeFines++;
        } else if (event.severity === 'MEDIUM') {
          mediumFines++;
        }
        break;
      case 'LATE_PAYMENT':
        latePayments++;
        break;
      case 'ACCIDENT':
        accidents++;
        break;
      case 'MAINTENANCE':
        maintenanceCount++;
        break;
      case 'HEAVY_USE':
        heavyUseCount++;
        totalKm += 100 + Math.random() * 500;
        break;
    }
  }

  totalKm += vehicle.estimatedMileage;

  const currentYear = new Date().getFullYear();
  const vehicleAge = currentYear - vehicle.year;

  return {
    severeFines,
    mediumFines,
    totalKm,
    latePayments,
    customerAge: customer.age,
    vehicleAge,
    accidents,
    maintenanceCount,
    heavyUseCount,
  };
}

/**
 * Generate a random feature vector for batch processing
 */
export function generateRandomFeatureVector(
  seed?: number
): FeatureVector {
  const rng = new SeededRandom(seed);
  
  return {
    severeFines: rng.nextInt(0, 20),
    mediumFines: rng.nextInt(0, 50),
    totalKm: rng.nextFloat(10000, 200000),
    latePayments: rng.nextInt(0, 30),
    customerAge: rng.nextInt(18, 80),
    vehicleAge: rng.nextInt(0, 20),
    accidents: rng.nextInt(0, 5),
    maintenanceCount: rng.nextInt(0, 15),
    heavyUseCount: rng.nextInt(0, 100),
  };
}
