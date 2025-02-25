const std = @import("std");

pub fn select(
    comptime T: type,
    comptime weight_field: []const u8,
    table: []T,
    rnd: *std.rand.Random
) ?T {
    if (table.len > 0) {
        var max_weight: f64 = 0;
        for (table) |item| {
            max_weight += @field(item, weight_field);
        }

        const roll = rnd.float(f64) * max_weight;
        var prev_weight: f64 = 0;
        for (table) |item| {
            const item_weight = @field(item, weight_field);
            if (roll >= prev_weight and roll < prev_weight + item_weight) {
                return item;
            }
            prev_weight += item_weight;
        }
    }

    return null;
}