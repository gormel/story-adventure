const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const gui_setup = @import("../../../engine/gui_setup.zig");
const utils = @import("../../../engine/utils.zig");
const pr = @import("../../../engine/properties.zig");
const itm = @import("../../../engine/items.zig");
const rr = @import("../../../engine/rollrate.zig");
const easing = @import("../../render/easing.zig");
const sp = @import("../../../engine/sprite.zig");
const main_menu = @import("../mainMenu/mainmenu.zig");
const game_stats = @import("../gamestats/gamestats.zig");
const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const gscmp = @import("../gamestats/components.zig");

pub fn initGui(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "gameover-stats-root")) {
            reg.add(entity, cmp.AttachGamestats {});
        }
    }
}

pub fn gui(reg: *ecs.Registry, props: *pr.Properties, change: *game.ScenePropChangeCfg, allocator: std.mem.Allocator) !void {
    var continue_view = reg.view(.{ gcmp.ButtonClicked, gscmp.ContinueBtn }, .{});
    var continue_iter = continue_view.entityIterator();
    while (continue_iter.next()) |_| {
        game.destroyAll(gcmp.GameoverScene, reg);

        try main_menu.loadScene(reg, props, change, allocator);
    }

    var gamestats_view = reg.view(.{ cmp.AttachGamestats }, .{});
    var gamestats_iter = gamestats_view.entityIterator();
    while (gamestats_iter.next()) |entity| {
        reg.remove(cmp.AttachGamestats, entity);

        const scene_ety = try game_stats.loadScene(reg, props, change, allocator);
        reg.add(scene_ety, gscmp.InitState { .title = "Game Over" });
        if (reg.tryGet(rcmp.AttachTo, scene_ety)) |attach| {
            attach.target = entity;
        } else {
            reg.add(scene_ety, rcmp.AttachTo { .target = entity });
        }
    }
}