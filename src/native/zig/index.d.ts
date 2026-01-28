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

export interface SimulationResult {
  lossProbability: number;
  expectedLoss: number;
  confidenceInterval95: [number, number];
}

export interface Customer {
  id: string;
  age: number;
  relationshipYears: number;
  paymentHistory: number[];
}

export interface Vehicle {
  id: string;
  year: number;
  category: string;
  estimatedMileage: number;
}

export interface RiskReportResponse {
  customerId: string;
  vehicleId: string;
  features: FeatureVector;
  score: number;
  simulation: SimulationResult;
}

export interface BatchScoreStats {
  meanScore: number;
  stdDev: number;
  min: number;
  max: number;
}

export interface TemporalAggregation {
  lastMonth: number;
  lastQuarter: number;
  lastYear: number;
}

export interface AnalyticsSummary {
  totalEvents: number;
  eventsByCategory: Record<string, number>;
  temporalAggregation: TemporalAggregation;
  averageTimeBetweenEventsDays: number;
}

export interface ZigNativeModule {
  analyzeCustomerHistory(
    customerId: string,
    vehicleId: string,
    historySize: number,
    seed?: number
  ): AnalyticsSummary;

  generateRiskReport(
    customerId: string,
    vehicleId: string,
    historySize: number,
    simulationIterations: number,
    seed: number | undefined,
    customer: Customer,
    vehicle: Vehicle
  ): RiskReportResponse;

  batchScoreAnalysis(count: number, seed?: number): BatchScoreStats;

  calculateRiskScore(features: FeatureVector): number;
}

declare const addon: ZigNativeModule;
export default addon;
