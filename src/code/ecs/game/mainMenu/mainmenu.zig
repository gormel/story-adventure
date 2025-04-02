const std = @import("std");
const ecs = @import("zig-ecs");
const pr = @import("../../../engine/properties.zig");
const game = @import("../utils.zig");

pub const SCENE_NAME = "mainmenu";

pub fn loadScene(
        reg: *ecs.Registry,
        allocator: std.mem.Allocator
) !void {
    _ = try game.loadScene(reg, allocator, SCENE_NAME, .{});
}