use crate::types::SimulationResult;
use crate::random::SeededRandom;

pub fn monte_carlo_simulation(score: f64, iterations: u32, seed: Option<f64>) -> SimulationResult {
    let mut rng = SeededRandom::new(seed);
    let mut losses = Vec::with_capacity(iterations as usize);
    let mut total_loss = 0.0;
    let mut loss_count = 0;

    let base_loss_probability = score * 0.3;

    for _ in 0..iterations {
        let event_occurs = rng.next() < base_loss_probability;

        if event_occurs {
            loss_count += 1;

            let base_loss = 1000.0 + score * 10000.0;
            // baseLoss * (0.5 + rng.next() * 1.5)
            let loss_amount = base_loss * (0.5 + rng.next() * 1.5);

            losses.push(loss_amount);
            total_loss += loss_amount;
        } else {
            losses.push(0.0);
        }
    }

    let loss_probability = loss_count as f64 / iterations as f64;
    let expected_loss = total_loss / iterations as f64;

    // Sort to find percentiles
    // Rust f64 sorting needs handling of NaNs, though here we shouldn't have them.
    losses.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let idx_2_5 = (iterations as f64 * 0.025).floor() as usize;
    let idx_97_5 = (iterations as f64 * 0.975).floor() as usize;

    // Safety checks for indices
    let p2_5 = if idx_2_5 < losses.len() { losses[idx_2_5] } else { 0.0 };
    let p97_5 = if idx_97_5 < losses.len() { losses[idx_97_5] } else { 0.0 };

    SimulationResult {
        loss_probability,
        expected_loss,
        confidence_interval_95: vec![p2_5, p97_5],
    }
}
