const std = @import("std");

pub const SeededRandom = struct {
    seed: f64,

    pub fn init(seed: ?f64) SeededRandom {
        return SeededRandom{
            .seed = seed orelse 12345.0,
        };
    }

    pub fn next(self: *SeededRandom) f64 {
        // Rust: (self.seed * 9301.0 + 49297.0) % 233280.0;
        const new_seed = @mod((self.seed * 9301.0 + 49297.0), 233280.0);
        self.seed = new_seed;
        return self.seed / 233280.0;
    }

    pub fn nextInt(self: *SeededRandom, min: i32, max: i32) i32 {
        const n = self.next();
        const range = @as(f64, @floatFromInt(max - min));
        return @as(i32, @intFromFloat(@floor(n * range))) + min;
    }

    pub fn nextFloat(self: *SeededRandom, min: f64, max: f64) f64 {
        return self.next() * (max - min) + min;
    }

    pub fn choice(self: *SeededRandom, comptime T: type, array: []const T) T {
        const idx = self.nextInt(0, @as(i32, @intCast(array.len)));
        return array[@as(usize, @intCast(idx))];
    }
};
