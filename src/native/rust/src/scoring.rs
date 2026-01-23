use crate::types::FeatureVector;

const WEIGHTS: [f64; 9] = [
    0.15,   // severeFines
    0.08,   // mediumFines
    0.0001, // totalKm (normalized)
    0.12,   // latePayments
    0.05,   // customerAge (normalized)
    0.03,   // vehicleAge
    0.25,   // accidents
    -0.02,  // maintenanceCount
    -0.01,  // heavyUseCount
];

const BIAS: f64 = 0.5;

pub fn calculate_score(features: &FeatureVector) -> f64 {
    let feature_array = [
        features.severe_fines as f64,
        features.medium_fines as f64,
        features.total_km / 1000.0,
        features.late_payments as f64,
        features.customer_age as f64 / 100.0,
        features.vehicle_age as f64,
        features.accidents as f64,
        features.maintenance_count as f64,
        features.heavy_use_count as f64,
    ];

    let mut score = BIAS;
    for (i, weight) in WEIGHTS.iter().enumerate() {
        if i < feature_array.len() {
            score += weight * feature_array[i];
        }
    }

    1.0 / (1.0 + (-score).exp())
}
