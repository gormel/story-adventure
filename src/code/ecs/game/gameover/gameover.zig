const std = @import("std");
const ecs = @import("zig-ecs");
const pr = @import("../../../engine/properties.zig");
const game = @import("../utils.zig");
const gcmp = @import("../components.zig");

pub const SCENE_NAME = "gameover";

pub fn loadScene(
        reg: *ecs.Registry,
        allocator: std.mem.Allocator
) !ecs.Entity {
    const ety = try game.loadScene(reg, allocator, SCENE_NAME, .{});
    reg.add(ety, gcmp.SetInputCaptureScene {});
    return ety;
}