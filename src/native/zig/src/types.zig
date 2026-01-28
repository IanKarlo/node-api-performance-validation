const std = @import("std");

pub const FeatureVector = struct {
    severe_fines: i32,
    medium_fines: i32,
    total_km: f64,
    late_payments: i32,
    customer_age: i32,
    vehicle_age: i32,
    accidents: i32,
    maintenance_count: i32,
    heavy_use_count: i32,
};

pub const SimulationResult = struct {
    loss_probability: f64,
    expected_loss: f64,
    confidence_interval_95: [2]f64,
};

pub const RiskEvent = struct {
    timestamp: f64,
    event_type: []const u8,
    severity: []const u8,
    value: ?f64,
};

pub const Customer = struct {
    id: []const u8,
    age: i32,
    relationship_years: i32,
    payment_history: []const f64,
};

pub const Vehicle = struct {
    id: []const u8,
    year: i32,
    category: []const u8,
    estimated_mileage: f64,
};

pub const RiskReportResponse = struct {
    customer_id: []const u8,
    vehicle_id: []const u8,
    features: FeatureVector,
    score: f64,
    simulation: SimulationResult,
};

pub const BatchScoreStats = struct {
    mean_score: f64,
    std_dev: f64,
    min: f64,
    max: f64,
};

pub const TemporalAggregation = struct {
    last_month: i32,
    last_quarter: i32,
    last_year: i32,
};

pub const AnalyticsSummary = struct {
    total_events: i32,
    events_by_category: std.StringHashMap(i32),
    temporal_aggregation: TemporalAggregation,
    average_time_between_events_days: f64,
};
