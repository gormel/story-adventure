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
            reg.add(entity, cmp.AttachGamestats { .owner_scene = init.scene });
        }
    }
}

pub fn gui(reg: *ecs.Registry, props: *pr.Properties, allocator: std.mem.Allocator) !void {
    var continue_view = reg.view(.{ gscmp.Continue, cmp.GameStatsScene }, .{});
    var continue_iter = continue_view.entityIterator();
    while (continue_iter.next()) |entity| {
        const gamestats = reg.get(cmp.GameStatsScene, entity);
        
        if (!reg.has(ccmp.Destroyed, gamestats.gameover_scene)) {
            reg.add(gamestats.gameover_scene, ccmp.Destroyed {});
        }

        reg.remove(gscmp.Continue, entity);

        try props.save();

        try main_menu.loadScene(reg, allocator);
    }

    var gamestats_view = reg.view(.{ cmp.AttachGamestats }, .{});
    var gamestats_iter = gamestats_view.entityIterator();
    while (gamestats_iter.next()) |entity| {
        const attach = reg.get(cmp.AttachGamestats, entity);

        const scene_ety = try game_stats.loadScene(reg, allocator, "Game Over", false);
        reg.addOrReplace(scene_ety, rcmp.AttachTo { .target = entity });
        reg.add(scene_ety, cmp.GameStatsScene { .gameover_scene = attach.owner_scene });

        reg.remove(cmp.AttachGamestats, entity);
    }
}