import { FeatureVector } from '../types';

const WEIGHTS: number[] = [
  0.15,
  0.08,
  0.0001,
  0.12,
  0.05,
  0.03,
  0.25,
  -0.02,
  -0.01,
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
