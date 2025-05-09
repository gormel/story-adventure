const std = @import("std");
const ecs = @import("zig-ecs");
const pr = @import("../../../engine/properties.zig");
const game = @import("../utils.zig");
const gcmp = @import("../components.zig");
const cmp = @import("components.zig");

pub const SCENE_NAME = "itemcollection";

pub const ItemHoverViewCfg = struct {
    atlas: []const u8,
    image: []const u8,
};

pub const ItemCollectionCfg = struct {
    item_hover_view: ItemHoverViewCfg,
};

pub fn loadScene(
        reg: *ecs.Registry,
        allocator: std.mem.Allocator,
) !ecs.Entity {
    const ety = try game.loadScene(reg, allocator, SCENE_NAME, .{});
    reg.add(ety, gcmp.SetInputCaptureScene {});
    return ety;
}