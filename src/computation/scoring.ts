import { FeatureVector } from '../types';

/**
 * Linear model weights (hardcoded for baseline)
 * These can be configured or loaded from a file in production
 */
const WEIGHTS: number[] = [
  0.15,  // severeFines
  0.08,  // mediumFines
  0.0001, // totalKm (normalized)
  0.12,  // latePayments
  0.05,  // customerAge (normalized)
  0.03,  // vehicleAge
  0.25,  // accidents
  -0.02, // maintenanceCount (negative - maintenance is good)
  -0.01, // heavyUseCount (negative - but less impact)
];

const BIAS = 0.5;

/**
 * Calculate risk score using linear model: score = W * X + b
 * 
 * @param features Feature vector
 * @returns Risk score (typically 0-1 range, but can exceed)
 */
export function calculateScore(features: FeatureVector): number {
  const featureArray = [
    features.severeFines,
    features.mediumFines,
    features.totalKm / 1000,
    features.latePayments,
    features.customerAge / 100,
    features.vehicleAge,
    features.accidents,
    features.maintenanceCount,
    features.heavyUseCount,
  ];

  let score = BIAS;
  for (let i = 0; i < WEIGHTS.length && i < featureArray.length; i++) {
    score += WEIGHTS[i] * featureArray[i];
  }

  return 1 / (1 + Math.exp(-score));
}

/**
 * Batch score calculation using matrix multiplication approach
 * 
 * @param featureVectors Array of feature vectors
 * @returns Array of scores
 */
export function batchScore(featureVectors: FeatureVector[]): number[] {
  const scores: number[] = new Array(featureVectors.length);

  for (let i = 0; i < featureVectors.length; i++) {
    scores[i] = calculateScore(featureVectors[i]);
  }

  return scores;
}

/**
 * Calculate statistics for a batch of scores
 */
export function calculateScoreStatistics(scores: number[]): {
  meanScore: number;
  stdDev: number;
  min: number;
  max: number;
} {
  if (scores.length === 0) {
    return {
      meanScore: 0,
      stdDev: 0,
      min: 0,
      max: 0,
    };
  }

  const sum = scores.reduce((acc, score) => acc + score, 0);
  const mean = sum / scores.length;

  const variance = scores.reduce((acc, score) => {
    const diff = score - mean;
    return acc + diff * diff;
  }, 0) / scores.length;

  const stdDev = Math.sqrt(variance);
  const min = Math.min(...scores);
  const max = Math.max(...scores);

  return {
    meanScore: mean,
    stdDev,
    min,
    max,
  };
}
