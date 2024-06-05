const std = @import("std");
const rl = @import("raylib");

pub fn rotate(x: *f32, y: *f32, a: f32) void {
    const rad = std.math.degreesToRadians(f32, -a);
    const cos = std.math.cos(rad);
    const sin = std.math.sin(rad);

    const _x = x.*;
    const _y = y.*;

    x.* = _x * cos + _y * sin;
    y.* = -_x * sin + _y * cos;
}

pub fn containsTag(tags: [][]const u8, tag: []const u8) bool {
    for (tags) |mb_tag| {
        if (std.mem.eql(u8, mb_tag, tag)) {
            return true;
        }
    }

    return false;
}