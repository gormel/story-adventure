const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const utils = @import("../../../engine/utils.zig");
const pr = @import("../../../engine/properties.zig");

const cmp = @import("components.zig");
const gcmp = @import("../components.zig");
const scmp = @import("../../scene/components.zig");
const ccmp = @import("../../core/components.zig");
const iccmp = @import("../itemcollection/components.zig");
const rcmp = @import("../../render/components.zig");

const itemcollection = @import("../itemcollection/itemcollection.zig");

const initial_game_scene = "gameplaystart";

pub fn initGui(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "mainmenu-startgame-btn")) {
            reg.add(entity, cmp.StartGameBtn {});
        }

        if (utils.containsTag(init.tags, "mainmenu-items-btn")) {
            reg.add(entity, cmp.ItemsBtn {});
        }

        if (utils.containsTag(init.tags, "mainmenu-popup-root")) {
            reg.add(entity, cmp.PopupRoot {});
        }
        
        if (utils.containsTag(init.tags, "init-main-menu")) {
            var state_view = reg.view(.{ gcmp.GameState }, .{ gcmp.GameStateMenu });
            var state_iter = state_view.entityIterator();
            while (state_iter.next()) |state_entity| {
                reg.add(state_entity, gcmp.GameStateMenu {
                    .menu_scene = init.scene,
                });
            }
        }
    }
}

pub fn gui(reg: *ecs.Registry, props: *pr.Properties, change: *game.ScenePropChangeCfg, allocator: std.mem.Allocator) !void {
    var start_view = reg.view(.{ cmp.StartGameBtn, gcmp.ButtonClicked }, .{});
    var start_iter = start_view.entityIterator();
    while (start_iter.next()) |_| {
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

        const scene_ety = try game.loadScene(reg, allocator, initial_game_scene, .{
            .props = props,
            .change = change,
        });
        reg.addOrReplace(scene_ety, rcmp.Order { .order = game.RenderLayers.GAMEPLAY });
    }

    var items_view = reg.view(.{ gcmp.ButtonClicked, cmp.ItemsBtn }, .{});
    var items_iter = items_view.entityIterator();
    while (items_iter.next()) |_| {
        var root_iter = reg.entityIterator(cmp.PopupRoot);
        while (root_iter.next()) |root_ety| {
            const scene = try itemcollection.loadScene(reg, allocator);
            reg.add(scene, cmp.ItemCollectionScene {});
            reg.addOrReplace(scene, rcmp.AttachTo { .target = root_ety });
        }
    }

    var itemsclose_view = reg.view(.{ iccmp.Continue, cmp.ItemCollectionScene }, .{});
    var itemsclose_iter = itemsclose_view.entityIterator();
    while (itemsclose_iter.next()) |entity| {
        reg.remove(iccmp.Continue, entity);

        if (!reg.has(ccmp.Destroyed, entity)) {
            reg.add(entity, ccmp.Destroyed {});
        }
    }
}