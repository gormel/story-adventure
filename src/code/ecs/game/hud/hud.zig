const std = @import("std");
const ecs = @import("zig-ecs");
const pr = @import("../../../engine/properties.zig");
const game = @import("../utils.zig");

pub const SCENE_NAME = "hud";

pub fn loadScene(
        reg: *ecs.Registry,
        allocator: std.mem.Allocator
) !ecs.Entity {
    return try game.loadScene(reg, allocator, SCENE_NAME, .{});
}