const std = @import("std");
const types = @import("types.zig");

const WEIGHTS = [_]f64{
    0.15,   // severeFines
    0.08,   // mediumFines
    0.0001, // totalKm (normalized)
    0.12,   // latePayments
    0.05,   // customerAge (normalized)
    0.03,   // vehicleAge
    0.25,   // accidents
    -0.02,  // maintenanceCount
    -0.01,  // heavyUseCount
};

const BIAS: f64 = 0.5;

pub fn calculateScore(features: types.FeatureVector) f64 {
    const feature_array = [_]f64{
        @as(f64, @floatFromInt(features.severe_fines)),
        @as(f64, @floatFromInt(features.medium_fines)),
        features.total_km / 1000.0,
        @as(f64, @floatFromInt(features.late_payments)),
        @as(f64, @floatFromInt(features.customer_age)) / 100.0,
        @as(f64, @floatFromInt(features.vehicle_age)),
        @as(f64, @floatFromInt(features.accidents)),
        @as(f64, @floatFromInt(features.maintenance_count)),
        @as(f64, @floatFromInt(features.heavy_use_count)),
    };

    var score = BIAS;
    for (WEIGHTS, 0..) |weight, i| {
        if (i < feature_array.len) {
            score += weight * feature_array[i];
        }
    }

    return 1.0 / (1.0 + @exp(-score));
}
