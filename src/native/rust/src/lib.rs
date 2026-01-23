#![deny(clippy::all)]

#[macro_use]
extern crate napi_derive;

pub mod types;
pub mod random;
pub mod scoring;
pub mod simulation;
pub mod history;

use types::{RiskReportResponse, Customer, Vehicle, BatchScoreStats, FeatureVector};
use random::SeededRandom;

#[napi]
pub fn generate_risk_report(
  customer_id: String,
  vehicle_id: String,
  history_size: u32,
  simulation_iterations: u32,
  seed: Option<f64>,
  customer: Customer,
  vehicle: Vehicle,
) -> RiskReportResponse {
  let mut rng = SeededRandom::new(seed);
  
  // 1. History Generation
  let events = history::generate_history(history_size, &mut rng);
  
  // 2. Aggregation & 3. Feature Derivation
  let features = history::derive_features(&events, &customer, &vehicle, &mut rng);
  
  // 4. Score Calculation
  let score = scoring::calculate_score(&features);
  
  // 5. Simulation
  let simulation = simulation::monte_carlo_simulation(score, simulation_iterations, seed);
  
  RiskReportResponse {
    customer_id,
    vehicle_id,
    features,
    score,
    simulation,
  }
}

#[napi]
pub fn batch_score_analysis(count: u32, seed: Option<f64>) -> BatchScoreStats {
  let mut rng = SeededRandom::new(seed);
  let mut scores = Vec::with_capacity(count as usize);
  
  for _ in 0..count {
    let features = history::generate_random_feature_vector(&mut rng);
    scores.push(scoring::calculate_score(&features));
  }
  
  let len = scores.len() as f64;
  if len == 0.0 {
      return BatchScoreStats { mean_score: 0.0, std_dev: 0.0, min: 0.0, max: 0.0 };
  }
  
  let sum: f64 = scores.iter().sum();
  let mean = sum / len;
  
  let variance = scores.iter().map(|score| {
      let diff = score - mean;
      diff * diff
  }).sum::<f64>() / len;
  
  let std_dev = variance.sqrt();
  
  let mut min = scores[0];
  let mut max = scores[0];
  
  for &score in &scores {
      if score < min { min = score; }
      if score > max { max = score; }
  }
  
  BatchScoreStats {
      mean_score: mean,
      std_dev,
      min,
      max,
  }
}

#[napi]
pub fn calculate_risk_score(features: FeatureVector) -> f64 {
    scoring::calculate_score(&features)
}
