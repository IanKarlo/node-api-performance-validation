use napi_derive::napi;

#[napi(object)]
#[derive(Clone, Debug)]
pub struct FeatureVector {
  pub severe_fines: i32,
  pub medium_fines: i32,
  pub total_km: f64,
  pub late_payments: i32,
  pub customer_age: i32,
  pub vehicle_age: i32,
  pub accidents: i32,
  pub maintenance_count: i32,
  pub heavy_use_count: i32,
}

#[napi(object)]
#[derive(Clone, Debug)]
pub struct SimulationResult {
  pub loss_probability: f64,
  pub expected_loss: f64,
  pub confidence_interval_95: Vec<f64>,
}

#[napi(object)]
#[derive(Clone, Debug)]
pub struct RiskEvent {
  pub timestamp: f64, // JS Date timestamp
  pub event_type: String,
  pub severity: String,
  pub value: Option<f64>,
}

#[napi(object)]
#[derive(Clone, Debug)]
pub struct Customer {
  pub id: String,
  pub age: i32,
  pub relationship_years: i32,
  pub payment_history: Vec<f64>, // number[] in TS
}

#[napi(object)]
#[derive(Clone, Debug)]
pub struct Vehicle {
  pub id: String,
  pub year: i32,
  pub category: String, // 'sedan' | 'suv' | ...
  pub estimated_mileage: f64,
}

#[napi(object)]
#[derive(Clone, Debug)]
pub struct RiskReportResponse {
  pub customer_id: String,
  pub vehicle_id: String,
  pub features: FeatureVector,
  pub score: f64,
  pub simulation: SimulationResult,
}

#[napi(object)]
#[derive(Clone, Debug)]
pub struct BatchScoreStats {
  pub mean_score: f64,
  pub std_dev: f64,
  pub min: f64,
  pub max: f64,
}
