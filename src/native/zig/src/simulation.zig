const std = @import("std");
const types = @import("types.zig");
const SeededRandom = @import("random.zig").SeededRandom;

pub fn monteCarloSimulation(allocator: std.mem.Allocator, score: f64, iterations: u32, seed: ?f64) !types.SimulationResult {
    var rng = SeededRandom.init(seed);
    var losses = try std.ArrayList(f64).initCapacity(allocator, iterations);
    defer losses.deinit(allocator);

    var total_loss: f64 = 0.0;
    var loss_count: u32 = 0;

    const base_loss_probability = score * 0.3;

    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        const event_occurs = rng.next() < base_loss_probability;

        if (event_occurs) {
            loss_count += 1;

            const base_loss = 1000.0 + score * 10000.0;
            const loss_amount = base_loss * (0.5 + rng.next() * 1.5);

            losses.appendAssumeCapacity(loss_amount);
            total_loss += loss_amount;
        } else {
            losses.appendAssumeCapacity(0.0);
        }
    }

    const loss_probability = @as(f64, @floatFromInt(loss_count)) / @as(f64, @floatFromInt(iterations));
    const expected_loss = total_loss / @as(f64, @floatFromInt(iterations));

    std.sort.block(f64, losses.items, {}, std.sort.asc(f64));

    const idx_2_5 = @as(usize, @intFromFloat(@floor(@as(f64, @floatFromInt(iterations)) * 0.025)));
    const idx_97_5 = @as(usize, @intFromFloat(@floor(@as(f64, @floatFromInt(iterations)) * 0.975)));

    const p2_5 = if (idx_2_5 < losses.items.len) losses.items[idx_2_5] else 0.0;
    const p97_5 = if (idx_97_5 < losses.items.len) losses.items[idx_97_5] else 0.0;

    return types.SimulationResult{
        .loss_probability = loss_probability,
        .expected_loss = expected_loss,
        .confidence_interval_95 = .{ p2_5, p97_5 },
    };
}
