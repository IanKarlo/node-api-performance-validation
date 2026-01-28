const std = @import("std");
const types = @import("types.zig");

pub fn calculateCustomerAnalytics(
    allocator: std.mem.Allocator,
    events: []const types.RiskEvent,
) !types.AnalyticsSummary {
    const now = 1706000000000.0;

    const one_month_ago = now - 30.0 * 24.0 * 60.0 * 60.0 * 1000.0;
    const one_quarter_ago = now - 90.0 * 24.0 * 60.0 * 60.0 * 1000.0;
    const one_year_ago = now - 365.0 * 24.0 * 60.0 * 60.0 * 1000.0;

    var events_by_category = std.StringHashMap(i32).init(allocator);

    var last_month_count: i32 = 0;
    var last_quarter_count: i32 = 0;
    var last_year_count: i32 = 0;

    var timestamps = try std.ArrayList(f64).initCapacity(allocator, events.len);
    defer timestamps.deinit(allocator);

    for (events) |event| {
        const result = try events_by_category.getOrPut(event.event_type);
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
        result.value_ptr.* += 1;

        timestamps.appendAssumeCapacity(event.timestamp);

        if (event.timestamp >= one_month_ago) {
            last_month_count += 1;
        }
        if (event.timestamp >= one_quarter_ago) {
            last_quarter_count += 1;
        }
        if (event.timestamp >= one_year_ago) {
            last_year_count += 1;
        }
    }

    var average_time_between_events_days: f64 = 0.0;
    if (timestamps.items.len > 1) {
        std.sort.block(f64, timestamps.items, {}, std.sort.asc(f64));

        var total_diff: f64 = 0.0;
        var i: usize = 1;
        while (i < timestamps.items.len) : (i += 1) {
            total_diff += timestamps.items[i] - timestamps.items[i - 1];
        }

        average_time_between_events_days = (total_diff / @as(f64, @floatFromInt(timestamps.items.len - 1))) / (24.0 * 60.0 * 60.0 * 1000.0);
    }

    return types.AnalyticsSummary{
        .total_events = @as(i32, @intCast(events.len)),
        .events_by_category = events_by_category,
        .temporal_aggregation = types.TemporalAggregation{
            .last_month = last_month_count,
            .last_quarter = last_quarter_count,
            .last_year = last_year_count,
        },
        .average_time_between_events_days = average_time_between_events_days,
    };
}
