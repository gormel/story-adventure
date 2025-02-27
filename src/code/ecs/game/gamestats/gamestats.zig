const std = @import("std");
const ecs = @import("zig-ecs");
const pr = @import("../../../engine/properties.zig");
const game = @import("../utils.zig");

pub const SCENE_NAME = "gamestats";

pub fn loadScene(
        reg: *ecs.Registry,
        props: *pr.Properties,
        change: *game.ScenePropChangeCfg,
        allocator: std.mem.Allocator
) !ecs.Entity {
    return try game.loadScene(reg, props, change, allocator, SCENE_NAME);
}