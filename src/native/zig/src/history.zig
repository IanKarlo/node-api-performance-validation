const std = @import("std");
const types = @import("types.zig");
const SeededRandom = @import("random.zig").SeededRandom;

pub fn generateHistory(allocator: std.mem.Allocator, history_size: u32, rng: *SeededRandom) !std.ArrayList(types.RiskEvent) {
    var events = try std.ArrayList(types.RiskEvent).initCapacity(allocator, history_size);

    const now = 1706000000000.0;
    const one_year_ago = now - 365.0 * 24.0 * 60.0 * 60.0 * 1000.0;

    const event_types = [_][]const u8{ "FINE", "HEAVY_USE", "LATE_PAYMENT", "ACCIDENT", "MAINTENANCE" };
    const severities = [_][]const u8{ "LOW", "MEDIUM", "HIGH", "CRITICAL" };

    var i: u32 = 0;
    while (i < history_size) : (i += 1) {
        const timestamp = one_year_ago + rng.next() * (now - one_year_ago);
        const type_str = rng.choice([]const u8, &event_types);
        const severity = rng.choice([]const u8, &severities);

        var value: ?f64 = null;
        if (std.mem.eql(u8, type_str, "FINE") or std.mem.eql(u8, type_str, "ACCIDENT")) {
            var base_value: f64 = 100.0;
            if (std.mem.eql(u8, severity, "CRITICAL")) {
                base_value = 5000.0;
            } else if (std.mem.eql(u8, severity, "HIGH")) {
                base_value = 2000.0;
            } else if (std.mem.eql(u8, severity, "MEDIUM")) {
                base_value = 500.0;
            }
            value = base_value * (0.5 + rng.next());
        }

        events.appendAssumeCapacity(types.RiskEvent{
            .timestamp = timestamp,
            .event_type = type_str,
            .severity = severity,
            .value = value,
        });
    }

    const sort = struct {
        pub fn lessThan(_: void, lhs: types.RiskEvent, rhs: types.RiskEvent) bool {
            return lhs.timestamp < rhs.timestamp;
        }
    };
    std.sort.block(types.RiskEvent, events.items, {}, sort.lessThan);

    return events;
}

pub fn deriveFeatures(
    events: []const types.RiskEvent,
    customer: types.Customer,
    vehicle: types.Vehicle,
    rng: *SeededRandom,
) types.FeatureVector {
    var severe_fines: i32 = 0;
    var medium_fines: i32 = 0;
    var total_km: f64 = 0.0;
    var late_payments: i32 = 0;
    var accidents: i32 = 0;
    var maintenance_count: i32 = 0;
    var heavy_use_count: i32 = 0;

    for (events) |event| {
        if (std.mem.eql(u8, event.event_type, "FINE")) {
            if (std.mem.eql(u8, event.severity, "HIGH") or std.mem.eql(u8, event.severity, "CRITICAL")) {
                severe_fines += 1;
            } else if (std.mem.eql(u8, event.severity, "MEDIUM")) {
                medium_fines += 1;
            }
        } else if (std.mem.eql(u8, event.event_type, "LATE_PAYMENT")) {
            late_payments += 1;
        } else if (std.mem.eql(u8, event.event_type, "ACCIDENT")) {
            accidents += 1;
        } else if (std.mem.eql(u8, event.event_type, "MAINTENANCE")) {
            maintenance_count += 1;
        } else if (std.mem.eql(u8, event.event_type, "HEAVY_USE")) {
            heavy_use_count += 1;
            total_km += 100.0 + rng.next() * 500.0;
        }
    }

    total_km += vehicle.estimated_mileage;

    const current_year = 2026;
    const vehicle_age = current_year - vehicle.year;

    return types.FeatureVector{
        .severe_fines = severe_fines,
        .medium_fines = medium_fines,
        .total_km = total_km,
        .late_payments = late_payments,
        .customer_age = customer.age,
        .vehicle_age = vehicle_age,
        .accidents = accidents,
        .maintenance_count = maintenance_count,
        .heavy_use_count = heavy_use_count,
    };
}

pub fn generateRandomFeatureVector(rng: *SeededRandom) types.FeatureVector {
    return types.FeatureVector{
        .severe_fines = rng.nextInt(0, 20),
        .medium_fines = rng.nextInt(0, 50),
        .total_km = rng.nextFloat(10000.0, 200000.0),
        .late_payments = rng.nextInt(0, 30),
        .customer_age = rng.nextInt(18, 80),
        .vehicle_age = rng.nextInt(0, 20),
        .accidents = rng.nextInt(0, 5),
        .maintenance_count = rng.nextInt(0, 15),
        .heavy_use_count = rng.nextInt(0, 100),
    };
}
