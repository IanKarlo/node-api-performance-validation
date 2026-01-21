import { Vehicle } from '../types';

/**
 * Mock vehicle service - in production this would fetch from a database
 */
export class VehicleService {
  private vehicles: Map<string, Vehicle> = new Map();

  /**
   * Get or create a vehicle
   */
  getVehicle(vehicleId: string): Vehicle {
    if (!this.vehicles.has(vehicleId)) {
      const currentYear = new Date().getFullYear();
      const year = currentYear - Math.floor(Math.random() * 20);
      const categories: Vehicle['category'][] = ['sedan', 'suv', 'truck', 'motorcycle'];
      const category = categories[Math.floor(Math.random() * categories.length)];
      const estimatedMileage = 10000 + Math.random() * 150000;

      this.vehicles.set(vehicleId, {
        id: vehicleId,
        year,
        category,
        estimatedMileage,
      });
    }

    return this.vehicles.get(vehicleId)!;
  }
}
