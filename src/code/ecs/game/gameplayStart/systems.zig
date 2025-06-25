const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const utils = @import("../../../engine/utils.zig");
const pr = @import("../../../engine/properties.zig");
const hud = @import("../hud/hud.zig");
const gameplaystart = @import("gameplaystart.zig");
const it = @import("../../../engine/items.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const gcmp = @import("../components.zig");
const rcmp = @import("../../render/components.zig");

const cfg_text = @embedFile("../../../assets/cfg/scene_customs/gameplaystart.json");

pub fn initSwitch(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "init-gameplay-start")) {

            const hud_scene = try hud.loadScene(reg, allocator);
            reg.addOrReplace(hud_scene, rcmp.Order { .order = game.RenderLayers.HUD });

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

pub fn doSwitch(reg: *ecs.Registry, items: *it.Items, allocator: std.mem.Allocator) !void {
    var view = reg.view(.{ cmp.Switch, scmp.GameObject }, .{ scmp.InitGameObject });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const cfg_json = try std.json.parseFromSlice(gameplaystart.GameplayStartCfg, allocator,
            cfg_text, .{ .ignore_unknown_fields = true });
        defer cfg_json.deinit();

        for (cfg_json.value.start_items) |item| {
            _ = try items.add(item);
        }

        game.selectNextScene(reg);
        reg.remove(cmp.Switch, entity);
    }
}