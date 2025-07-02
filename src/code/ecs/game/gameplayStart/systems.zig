const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const utils = @import("../../../engine/utils.zig");
const pr = @import("../../../engine/properties.zig");
const hud = @import("../hud/hud.zig");
const gameplaystart = @import("gameplaystart.zig");
const it = @import("../../../engine/items.zig");
const lore = @import("../lore/lore.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const gcmp = @import("../components.zig");
const rcmp = @import("../../render/components.zig");
const lcmp = @import("../lore/components.zig");
const ccmp = @import("../../core/components.zig");

const cfg_text = @embedFile("../../../assets/cfg/scene_customs/gameplaystart.json");
const cfg_lore_text = @embedFile("../../../assets/cfg/scene_lore/gameplaystart.json");

pub fn initSwitch(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "gameplaystart-init")) {
            const hud_scene = try hud.loadScene(reg, allocator);
            reg.addOrReplace(hud_scene, rcmp.Order { .order = game.RenderLayers.HUD });

            var state_view = reg.view(.{ gcmp.GameState }, .{ gcmp.GameStateGameplay });
            var state_iter = state_view.entityIterator();
            while (state_iter.next()) |state_entity| {
                reg.add(state_entity, gcmp.GameStateGameplay {
                    .hud_scene = hud_scene,
                });
            }
        }

        if (utils.containsTag(init.tags, "gameplaystart-lore-root")) {
            reg.add(entity, cmp.CreateLorePanel {});
        }
    }
}

pub fn updateLore(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var create_iter = reg.entityIterator(cmp.CreateLorePanel);
    while (create_iter.next()) |entity| {
        reg.remove(cmp.CreateLorePanel, entity);

        const cfg_json = try std.json.parseFromSlice(lore.LoreCfg, allocator, cfg_lore_text, .{});

        const panel = try lore.loadScene(reg, allocator, cfg_json.value);
        reg.add(panel, cmp.LorePanel { .cfg_json = cfg_json });
        reg.addOrReplace(panel, rcmp.AttachTo { .target = entity });
    }

    var continue_view = reg.view(.{ lcmp.Continue, cmp.LorePanel }, .{});
    var continue_iter = continue_view.entityIterator();
    while (continue_iter.next()) |entity| {
        reg.remove(lcmp.Continue, entity);
        const panel = reg.get(cmp.LorePanel, entity);

        defer panel.cfg_json.deinit();
        reg.addOrReplace(entity, ccmp.Destroyed {});

        reg.add(reg.create(), cmp.Switch {});
    }
}

pub fn doSwitch(reg: *ecs.Registry, items: *it.Items, allocator: std.mem.Allocator) !void {
    var view = reg.view(.{ cmp.Switch }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.remove(cmp.Switch, entity);
        reg.addOrReplace(entity, ccmp.Destroyed {});

        const cfg_json = try std.json.parseFromSlice(gameplaystart.GameplayStartCfg, allocator,
            cfg_text, .{ .ignore_unknown_fields = true });
        defer cfg_json.deinit();

        for (cfg_json.value.start_items) |item| {
            _ = try items.add(item);
        }

        game.selectNextScene(reg);
    }
}