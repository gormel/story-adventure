const std = @import("std");
const ecs = @import("zig-ecs");
const game = @import("../utils.zig");

const cmp = @import("components.zig");
const gcmp = @import("../components.zig");

pub const SCENE_NAME = "lore";

pub const WORD_TIME = 0.2;

pub const LoreCfg = struct {
    text: [][:0]const u8,
};

pub fn loadScene(
        reg: *ecs.Registry,
        allocator: std.mem.Allocator,
        cfg: LoreCfg
) !ecs.Entity {
    const ety = try game.loadScene(reg, allocator, SCENE_NAME, .{});
    reg.add(ety, gcmp.SetInputCaptureScene {});
    reg.add(ety, cmp.LoreScene { .cfg = cfg });
    return ety;
}