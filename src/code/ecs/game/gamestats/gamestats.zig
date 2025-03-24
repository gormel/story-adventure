const std = @import("std");
const ecs = @import("zig-ecs");
const pr = @import("../../../engine/properties.zig");
const game = @import("../utils.zig");
const gcmp = @import("../components.zig");
const cmp = @import("components.zig");

pub const SCENE_NAME = "gamestats";

pub const ItemHoverViewCfg = struct {
    atlas: []const u8,
    sprite: []const u8,
};

pub const GamestatsCfg = struct {
    item_hover_view: ItemHoverViewCfg,
};

pub fn loadScene(
        reg: *ecs.Registry,
        allocator: std.mem.Allocator,
        title: [:0] const u8,
        free_title: bool
) !ecs.Entity {
    const ety = try game.loadScene(reg, allocator, SCENE_NAME, .{});
    reg.add(ety, gcmp.SetInputCaptureScene {});
    reg.add(ety, cmp.SceneSetup { .title = title, .free_title = free_title });
    return ety;
}