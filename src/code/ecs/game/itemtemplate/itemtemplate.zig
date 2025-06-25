const std = @import("std");
const ecs = @import("zig-ecs");
const game = @import("../utils.zig");

const cmp = @import("components.zig");
const gcmp = @import("../components.zig");

pub const SCENE_NAME = "itemtemplate";

pub fn loadScene(
        reg: *ecs.Registry,
        allocator: std.mem.Allocator,
        item: []const u8,
        infopanel_root: ?ecs.Entity
) !ecs.Entity {
    const ety = try game.loadScene(reg, allocator, SCENE_NAME, .{});
    reg.add(ety, cmp.ItemTemplateScene { .infopanel_root = infopanel_root, .item = item });
    reg.add(ety, gcmp.TemplateInstanceScene {});
    return ety;
}