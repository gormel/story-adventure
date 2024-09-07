const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const cmp = @import("components.zig");
const utils = @import("../../../engine/utils.zig");
const scmp = @import("../../scene/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");

const Properties = @import("../../../engine/parameters.zig").Properties;

const initial_game_scene = "gameplay_start";

pub fn initStartButton(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "button-start-game")) {
            reg.add(entity, cmp.StartGameButton {});
        }
    }
}

pub fn initScene(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "init-main-menu")) {

            var state_view = reg.view(.{ gcmp.GameState }, .{ gcmp.GameStateMenu });
            var state_iter = state_view.entityIterator();
            while (state_iter.next()) |state_entity| {
                const scene_ety = game.queryScene(reg, entity);

                reg.add(state_entity, gcmp.GameStateMenu {
                    .menu_scene = scene_ety,
                });
            }
        }
    }
}

pub fn startGame(reg: *ecs.Registry, props: *Properties, allocator: std.mem.Allocator) !void {
    var view = reg.view(.{ cmp.StartGameButton, gcmp.ButtonClicked }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |_| {
        try props.reset();

        var state_view = reg.view(.{ gcmp.GameState, gcmp.GameStateMenu }, .{ });
        var state_iter = state_view.entityIterator();
        while (state_iter.next()) |state_entity| {
            const menu_state = reg.get(gcmp.GameStateMenu, state_entity);
            if (menu_state.menu_scene) |scene_ety| {
                reg.add(scene_ety, ccmp.Destroyed {});
            }

            reg.remove(gcmp.GameStateMenu, state_entity);
        }

        _ = try game.loadScene(reg, allocator, initial_game_scene);
    }
}