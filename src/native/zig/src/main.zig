const std = @import("std");
const c = @cImport({
    @cInclude("node_api.h");
});
const history = @import("history.zig");
const scoring = @import("scoring.zig");
const simulation = @import("simulation.zig");
const analytics = @import("analytics.zig");
const types = @import("types.zig");
const random = @import("random.zig");

// --- Helper Functions ---

fn check(status: c.napi_status) void {
    if (status != c.napi_ok) unreachable; // Simple panic on N-API error for now
}

fn getInt32(env: c.napi_env, value: c.napi_value) i32 {
    var result: i32 = 0;
    check(c.napi_get_value_int32(env, value, &result));
    return result;
}

fn getDouble(env: c.napi_env, value: c.napi_value) f64 {
    var result: f64 = 0;
    check(c.napi_get_value_double(env, value, &result));
    return result;
}

fn getString(env: c.napi_env, value: c.napi_value, allocator: std.mem.Allocator) ![]const u8 {
    var len: usize = 0;
    check(c.napi_get_value_string_utf8(env, value, null, 0, &len));
    const buf = try allocator.alloc(u8, len + 1);
    check(c.napi_get_value_string_utf8(env, value, buf.ptr, len + 1, &len));
    return buf[0..len];
}

fn getNamedProp(env: c.napi_env, object: c.napi_value, name: [:0]const u8) c.napi_value {
    var result: c.napi_value = undefined;
    check(c.napi_get_named_property(env, object, name.ptr, &result));
    return result;
}

fn createDouble(env: c.napi_env, value: f64) c.napi_value {
    var result: c.napi_value = undefined;
    check(c.napi_create_double(env, value, &result));
    return result;
}

fn createInt32(env: c.napi_env, value: i32) c.napi_value {
    var result: c.napi_value = undefined;
    check(c.napi_create_int32(env, value, &result));
    return result;
}

fn createString(env: c.napi_env, value: []const u8) c.napi_value {
    var result: c.napi_value = undefined;
    check(c.napi_create_string_utf8(env, value.ptr, value.len, &result));
    return result;
}

fn createObject(env: c.napi_env) c.napi_value {
    var result: c.napi_value = undefined;
    check(c.napi_create_object(env, &result));
    return result;
}

fn setNamedProp(env: c.napi_env, object: c.napi_value, name: [:0]const u8, value: c.napi_value) void {
    check(c.napi_set_named_property(env, object, name.ptr, value));
}

fn getType(env: c.napi_env, value: c.napi_value) c.napi_valuetype {
    var result: c.napi_valuetype = undefined;
    check(c.napi_typeof(env, value, &result));
    return result;
}

// --- Converters ---

fn jsToCustomer(env: c.napi_env, obj: c.napi_value, allocator: std.mem.Allocator) !types.Customer {
    const id = try getString(env, getNamedProp(env, obj, "id"), allocator);
    const age = getInt32(env, getNamedProp(env, obj, "age"));
    const rel_years = getInt32(env, getNamedProp(env, obj, "relationshipYears"));

    const payment_history_js = getNamedProp(env, obj, "paymentHistory");
    var len: u32 = 0;
    check(c.napi_get_array_length(env, payment_history_js, &len));

    var payment_history = try allocator.alloc(f64, len);
    var i: u32 = 0;
    while (i < len) : (i += 1) {
        var elem: c.napi_value = undefined;
        check(c.napi_get_element(env, payment_history_js, i, &elem));
        payment_history[i] = getDouble(env, elem);
    }

    return types.Customer{
        .id = id,
        .age = age,
        .relationship_years = rel_years,
        .payment_history = payment_history,
    };
}

fn jsToVehicle(env: c.napi_env, obj: c.napi_value, allocator: std.mem.Allocator) !types.Vehicle {
    const id = try getString(env, getNamedProp(env, obj, "id"), allocator);
    const year = getInt32(env, getNamedProp(env, obj, "year"));
    const category = try getString(env, getNamedProp(env, obj, "category"), allocator);
    const est_mileage = getDouble(env, getNamedProp(env, obj, "estimatedMileage"));

    return types.Vehicle{
        .id = id,
        .year = year,
        .category = category,
        .estimated_mileage = est_mileage,
    };
}

fn jsToFeatureVector(env: c.napi_env, obj: c.napi_value) types.FeatureVector {
    return types.FeatureVector{
        .severe_fines = getInt32(env, getNamedProp(env, obj, "severeFines")),
        .medium_fines = getInt32(env, getNamedProp(env, obj, "mediumFines")),
        .total_km = getDouble(env, getNamedProp(env, obj, "totalKm")),
        .late_payments = getInt32(env, getNamedProp(env, obj, "latePayments")),
        .customer_age = getInt32(env, getNamedProp(env, obj, "customerAge")),
        .vehicle_age = getInt32(env, getNamedProp(env, obj, "vehicleAge")),
        .accidents = getInt32(env, getNamedProp(env, obj, "accidents")),
        .maintenance_count = getInt32(env, getNamedProp(env, obj, "maintenanceCount")),
        .heavy_use_count = getInt32(env, getNamedProp(env, obj, "heavyUseCount")),
    };
}

fn featureVectorToJs(env: c.napi_env, fv: types.FeatureVector) c.napi_value {
    const obj = createObject(env);
    setNamedProp(env, obj, "severeFines", createInt32(env, fv.severe_fines));
    setNamedProp(env, obj, "mediumFines", createInt32(env, fv.medium_fines));
    setNamedProp(env, obj, "totalKm", createDouble(env, fv.total_km));
    setNamedProp(env, obj, "latePayments", createInt32(env, fv.late_payments));
    setNamedProp(env, obj, "customerAge", createInt32(env, fv.customer_age));
    setNamedProp(env, obj, "vehicleAge", createInt32(env, fv.vehicle_age));
    setNamedProp(env, obj, "accidents", createInt32(env, fv.accidents));
    setNamedProp(env, obj, "maintenanceCount", createInt32(env, fv.maintenance_count));
    setNamedProp(env, obj, "heavyUseCount", createInt32(env, fv.heavy_use_count));
    return obj;
}

fn simulationResultToJs(env: c.napi_env, res: types.SimulationResult) c.napi_value {
    const obj = createObject(env);
    setNamedProp(env, obj, "lossProbability", createDouble(env, res.loss_probability));
    setNamedProp(env, obj, "expectedLoss", createDouble(env, res.expected_loss));

    var js_arr: c.napi_value = undefined;
    check(c.napi_create_array_with_length(env, 2, &js_arr));
    check(c.napi_set_element(env, js_arr, 0, createDouble(env, res.confidence_interval_95[0])));
    check(c.napi_set_element(env, js_arr, 1, createDouble(env, res.confidence_interval_95[1])));

    setNamedProp(env, obj, "confidenceInterval95", js_arr);
    return obj;
}

fn analyticsSummaryToJs(env: c.napi_env, summary: types.AnalyticsSummary) c.napi_value {
    const obj = createObject(env);
    setNamedProp(env, obj, "totalEvents", createInt32(env, summary.total_events));

    const cat_obj = createObject(env);
    var it = summary.events_by_category.iterator();
    while (it.next()) |entry| {
        const key_str = createString(env, entry.key_ptr.*);
        const val_num = createInt32(env, entry.value_ptr.*);
        check(c.napi_set_property(env, cat_obj, key_str, val_num));
    }
    setNamedProp(env, obj, "eventsByCategory", cat_obj);

    const temp_obj = createObject(env);
    setNamedProp(env, temp_obj, "lastMonth", createInt32(env, summary.temporal_aggregation.last_month));
    setNamedProp(env, temp_obj, "lastQuarter", createInt32(env, summary.temporal_aggregation.last_quarter));
    setNamedProp(env, temp_obj, "lastYear", createInt32(env, summary.temporal_aggregation.last_year));
    setNamedProp(env, obj, "temporalAggregation", temp_obj);

    setNamedProp(env, obj, "averageTimeBetweenEventsDays", createDouble(env, summary.average_time_between_events_days));

    return obj;
}

fn batchScoreStatsToJs(env: c.napi_env, stats: types.BatchScoreStats) c.napi_value {
    const obj = createObject(env);
    setNamedProp(env, obj, "meanScore", createDouble(env, stats.mean_score));
    setNamedProp(env, obj, "stdDev", createDouble(env, stats.std_dev));
    setNamedProp(env, obj, "min", createDouble(env, stats.min));
    setNamedProp(env, obj, "max", createDouble(env, stats.max));
    return obj;
}

// --- Exported Functions ---

// analyze_customer_history(customerId, vehicleId, historySize, seed)
fn analyze_customer_history(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var argc: usize = 4;
    var args: [4]c.napi_value = undefined;
    check(c.napi_get_cb_info(env, info, &argc, &args, null, null));

    if (argc < 4) return null;

    const history_size = getInt32(env, args[2]);

    var seed: ?f64 = null;
    if (getType(env, args[3]) == c.napi_number) {
        seed = getDouble(env, args[3]);
    }

    var rng = random.SeededRandom.init(seed);
    const events = history.generateHistory(allocator, @as(u32, @intCast(history_size)), &rng) catch return null;

    const summary = analytics.calculateCustomerAnalytics(allocator, events.items) catch return null;

    return analyticsSummaryToJs(env, summary);
}

// generate_risk_report(customerId, vehicleId, historySize, simulationIterations, seed, customer, vehicle)
fn generate_risk_report(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var argc: usize = 7;
    var args: [7]c.napi_value = undefined;
    check(c.napi_get_cb_info(env, info, &argc, &args, null, null));

    const customer_id = getString(env, args[0], allocator) catch return null;
    const vehicle_id = getString(env, args[1], allocator) catch return null;
    const history_size = getInt32(env, args[2]);
    const sim_iterations = getInt32(env, args[3]);

    var seed: ?f64 = null;
    if (getType(env, args[4]) == c.napi_number) {
        seed = getDouble(env, args[4]);
    }

    const customer = jsToCustomer(env, args[5], allocator) catch return null;
    const vehicle = jsToVehicle(env, args[6], allocator) catch return null;

    var rng = random.SeededRandom.init(seed);

    const events = history.generateHistory(allocator, @as(u32, @intCast(history_size)), &rng) catch return null;

    const features = history.deriveFeatures(events.items, customer, vehicle, &rng);

    const score = scoring.calculateScore(features);

    const sim_res = simulation.monteCarloSimulation(allocator, score, @as(u32, @intCast(sim_iterations)), seed) catch return null;

    const report = createObject(env);
    setNamedProp(env, report, "customerId", createString(env, customer_id));
    setNamedProp(env, report, "vehicleId", createString(env, vehicle_id));
    setNamedProp(env, report, "features", featureVectorToJs(env, features));
    setNamedProp(env, report, "score", createDouble(env, score));
    setNamedProp(env, report, "simulation", simulationResultToJs(env, sim_res));

    return report;
}

// batch_score_analysis(count, seed)
fn batch_score_analysis(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var argc: usize = 2;
    var args: [2]c.napi_value = undefined;
    check(c.napi_get_cb_info(env, info, &argc, &args, null, null));

    const count = getInt32(env, args[0]);
    var seed: ?f64 = null;
    if (getType(env, args[1]) == c.napi_number) {
        seed = getDouble(env, args[1]);
    }

    var rng = random.SeededRandom.init(seed);
    var scores = std.ArrayList(f64).initCapacity(allocator, @as(usize, @intCast(count))) catch return null;

    var i: i32 = 0;
    while (i < count) : (i += 1) {
        const features = history.generateRandomFeatureVector(&rng);
        scores.appendAssumeCapacity(scoring.calculateScore(features));
    }

    var mean: f64 = 0.0;
    var std_dev: f64 = 0.0;
    var min: f64 = 0.0;
    var max: f64 = 0.0;

    if (scores.items.len > 0) {
        var sum: f64 = 0.0;
        min = scores.items[0];
        max = scores.items[0];

        for (scores.items) |s| {
            sum += s;
            if (s < min) min = s;
            if (s > max) max = s;
        }
        mean = sum / @as(f64, @floatFromInt(scores.items.len));

        var var_sum: f64 = 0.0;
        for (scores.items) |s| {
            const diff = s - mean;
            var_sum += diff * diff;
        }
        std_dev = @sqrt(var_sum / @as(f64, @floatFromInt(scores.items.len)));
    }

    const stats = types.BatchScoreStats{
        .mean_score = mean,
        .std_dev = std_dev,
        .min = min,
        .max = max,
    };

    return batchScoreStatsToJs(env, stats);
}

// calculate_risk_score(features)
fn calculate_risk_score(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    var argc: usize = 1;
    var args: [1]c.napi_value = undefined;
    check(c.napi_get_cb_info(env, info, &argc, &args, null, null));

    const features = jsToFeatureVector(env, args[0]);
    const score = scoring.calculateScore(features);

    return createDouble(env, score);
}

// --- Registration ---

fn registerFn(env: c.napi_env, exports: c.napi_value, name: [:0]const u8, func: c.napi_callback) void {
    var fn_desc = c.napi_property_descriptor{
        .utf8name = name.ptr,
        .name = null,
        .method = func,
        .getter = null,
        .setter = null,
        .value = null,
        .attributes = c.napi_default,
        .data = null,
    };
    check(c.napi_define_properties(env, exports, 1, &fn_desc));
}

export fn napi_register_module_v1(env: c.napi_env, exports: c.napi_value) c.napi_value {
    registerFn(env, exports, "analyzeCustomerHistory", analyze_customer_history);
    registerFn(env, exports, "generateRiskReport", generate_risk_report);
    registerFn(env, exports, "batchScoreAnalysis", batch_score_analysis);
    registerFn(env, exports, "calculateRiskScore", calculate_risk_score);
    return exports;
}
