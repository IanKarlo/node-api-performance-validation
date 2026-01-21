// Core Entities
export interface Customer {
  id: string;
  age: number;
  relationshipYears: number;
  paymentHistory: number[];
}

export interface Vehicle {
  id: string;
  year: number;
  category: 'sedan' | 'suv' | 'truck' | 'motorcycle';
  estimatedMileage: number;
}

// Event used to compose the history
export interface RiskEvent {
  timestamp: Date;
  type: 'FINE' | 'HEAVY_USE' | 'LATE_PAYMENT' | 'ACCIDENT' | 'MAINTENANCE';
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  value?: number;
  metadata?: Record<string, any>;
}

// Feature Vector derived from history
export interface FeatureVector {
  severeFines: number;
  mediumFines: number;
  totalKm: number;
  latePayments: number;
  customerAge: number;
  vehicleAge: number;
  accidents: number;
  maintenanceCount: number;
  heavyUseCount: number;
}

// Monte Carlo Simulation Result
export interface SimulationResult {
  lossProbability: number;
  expectedLoss: number;
  confidenceInterval95: [number, number];
}

// Complete Risk Report Response
export interface RiskReportResponse {
  customerId: string;
  vehicleId: string;
  features: FeatureVector;
  score: number;
  simulation: SimulationResult;
}

// Request DTOs
export interface RiskReportRequest {
  customerId: string;
  vehicleId: string;
  historySize: number;
  simulationIterations: number;
  seed?: number;
}

export interface BatchScoreRequest {
  count: number;
  featureConfig?: Record<string, any>;
  seed?: number;
}

export interface BatchScoreResponse {
  totalProcessed: number;
  statistics: {
    meanScore: number;
    stdDev: number;
    min: number;
    max: number;
  };
}

export interface CustomerAnalyticsResponse {
  customerId: string;
  summary: {
    totalEvents: number;
    eventsByCategory: Record<string, number>;
    temporalAggregation: {
      lastMonth: number;
      lastQuarter: number;
      lastYear: number;
    };
    averageTimeBetweenEventsDays: number;
  };
}
