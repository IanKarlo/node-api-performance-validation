import { SimulationResult } from '../types';
import { SeededRandom } from './random';

/**
 * Monte Carlo simulation to estimate loss probability and expected value
 * 
 * @param score Risk score (0-1)
 * @param iterations Number of Monte Carlo iterations
 * @param seed Optional seed for reproducibility
 * @returns Simulation results
 */
export function monteCarloSimulation(
  score: number,
  iterations: number,
  seed?: number
): SimulationResult {
  const rng = new SeededRandom(seed);
  const losses: number[] = [];
  let totalLoss = 0;
  let lossCount = 0;

  const baseLossProbability = score * 0.3;

  for (let i = 0; i < iterations; i++) {
    const eventOccurs = rng.next() < baseLossProbability;

    if (eventOccurs) {
      lossCount++;

      const baseLoss = 1000 + score * 10000;
      const lossAmount = baseLoss * (0.5 + rng.next() * 1.5);
      
      losses.push(lossAmount);
      totalLoss += lossAmount;
    } else {
      losses.push(0);
    }
  }

  const lossProbability = lossCount / iterations;
  const expectedLoss = totalLoss / iterations;
  const sortedLosses = [...losses].sort((a, b) => a - b);
  const percentile2_5 = sortedLosses[Math.floor(iterations * 0.025)];
  const percentile97_5 = sortedLosses[Math.floor(iterations * 0.975)];

  return {
    lossProbability,
    expectedLoss,
    confidenceInterval95: [percentile2_5, percentile97_5],
  };
}
