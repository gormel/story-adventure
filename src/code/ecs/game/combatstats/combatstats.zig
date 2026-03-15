const std = @import("std");
const ecs = @import("zig-ecs");
const pr = @import("../../../engine/properties.zig");
const game = @import("../utils.zig");
const gcmp = @import("../components.zig");
const cmp = @import("components.zig");

pub const SCENE_NAME = "combatstats";

pub const CombatStats = struct { gold: f64, dmgtaken: f64, dmgdealt: f64 };

pub fn loadScene(
        reg: *ecs.Registry,
        allocator: std.mem.Allocator,
        stats: CombatStats
) !ecs.Entity {
    const ety = try game.loadScene(reg, allocator, SCENE_NAME, .{});
    reg.add(ety, gcmp.SetInputCaptureScene {});
    reg.add(ety, cmp.SceneSetup {
        .gold = stats.gold,
        .dmgdealt = stats.dmgdealt,
        .dmgtaken = stats.dmgtaken,
    });
    return ety;
}