use crate::types::{RiskEvent, FeatureVector, Customer, Vehicle};
use crate::random::SeededRandom;

pub fn generate_history(
    history_size: u32,
    rng: &mut SeededRandom,
) -> Vec<RiskEvent> {
    let mut events = Vec::with_capacity(history_size as usize);

    let now = 1706000000000.0;
    
    let one_year_ago = now - 365.0 * 24.0 * 60.0 * 60.0 * 1000.0;
    
    let event_types = ["FINE", "HEAVY_USE", "LATE_PAYMENT", "ACCIDENT", "MAINTENANCE"];
    let severities = ["LOW", "MEDIUM", "HIGH", "CRITICAL"];
    
    for _ in 0..history_size {
        let timestamp = one_year_ago + rng.next() * (now - one_year_ago);
        let type_str = rng.choice(&event_types).to_string();
        let severity = rng.choice(&severities).to_string();
        
        let mut value = None;
        if type_str == "FINE" || type_str == "ACCIDENT" {
            let base_value = match severity.as_str() {
                "CRITICAL" => 5000.0,
                "HIGH" => 2000.0,
                "MEDIUM" => 500.0,
                _ => 100.0,
            };
            value = Some(base_value * (0.5 + rng.next()));
        }
        
        events.push(RiskEvent {
            timestamp,
            event_type: type_str,
            severity,
            value,
        });
    }

    events.sort_by(|a, b| a.timestamp.partial_cmp(&b.timestamp).unwrap());
    
    events
}

pub fn derive_features(
    events: &[RiskEvent],
    customer: &Customer,
    vehicle: &Vehicle,
    rng: &mut SeededRandom,
) -> FeatureVector {
    let mut severe_fines = 0;
    let mut medium_fines = 0;
    let mut total_km = 0.0;
    let mut late_payments = 0;
    let mut accidents = 0;
    let mut maintenance_count = 0;
    let mut heavy_use_count = 0;
    
    for event in events {
        match event.event_type.as_str() {
            "FINE" => {
                if event.severity == "HIGH" || event.severity == "CRITICAL" {
                    severe_fines += 1;
                } else if event.severity == "MEDIUM" {
                    medium_fines += 1;
                }
            },
            "LATE_PAYMENT" => late_payments += 1,
            "ACCIDENT" => accidents += 1,
            "MAINTENANCE" => maintenance_count += 1,
            "HEAVY_USE" => {
                heavy_use_count += 1;
                total_km += 100.0 + rng.next() * 500.0;
            },
            _ => {}
        }
    }
    
    total_km += vehicle.estimated_mileage;

    let current_year = 2026;
    let vehicle_age = current_year - vehicle.year;
    
    
    FeatureVector {
        severe_fines,
        medium_fines,
        total_km,
        late_payments,
        customer_age: customer.age,
        vehicle_age,
        accidents,
        maintenance_count,
        heavy_use_count,
    }
}

pub fn generate_random_feature_vector(rng: &mut SeededRandom) -> FeatureVector {
    FeatureVector {
        severe_fines: rng.next_int(0, 20),
        medium_fines: rng.next_int(0, 50),
        total_km: rng.next_float(10000.0, 200000.0),
        late_payments: rng.next_int(0, 30),
        customer_age: rng.next_int(18, 80),
        vehicle_age: rng.next_int(0, 20),
        accidents: rng.next_int(0, 5),
        maintenance_count: rng.next_int(0, 15),
        heavy_use_count: rng.next_int(0, 100),
    }
}
