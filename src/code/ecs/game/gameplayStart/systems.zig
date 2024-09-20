const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const cmp = @import("components.zig");
const utils = @import("../../../engine/utils.zig");
const scmp = @import("../../scene/components.zig");
const gcmp = @import("../components.zig");
const pr = @import("../../../engine/properties.zig");

const hud_game_scene = "hud";

pub fn initSwitch(reg: *ecs.Registry, props: *pr.Properties, change: *game.ScenePropChangeCfg, allocator: std.mem.Allocator) !void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "init-gameplay-start")) {

            const hud_scene = try game.loadScene(reg, props, change, allocator, hud_game_scene);

            var state_view = reg.view(.{ gcmp.GameState }, .{ gcmp.GameStateGameplay });
            var state_iter = state_view.entityIterator();
            while (state_iter.next()) |state_entity| {
                reg.add(state_entity, gcmp.GameStateGameplay {
                    .hud_scene = hud_scene,
                });
            }

            reg.add(entity, cmp.Switch {});
        }
    }
}

pub fn doSwitch(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.Switch, scmp.GameObject }, .{ scmp.InitGameObject });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        game.selectNextScene(reg);
        reg.remove(cmp.Switch, entity);
    }
}