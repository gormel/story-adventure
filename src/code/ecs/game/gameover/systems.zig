const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const cmp = @import("components.zig");
const gui_setup = @import("../../../engine/gui_setup.zig");
const utils = @import("../../../engine/utils.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const pr = @import("../../../engine/properties.zig");
const itm = @import("../../../engine/items.zig");
const rr = @import("../../../engine/rollrate.zig");
const easing = @import("../../render/easing.zig");

const initial_scene = "main_menu";

pub fn initGui(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "gameover-button-continue")) {
            reg.add(entity, cmp.ContinueBtn {});
        }

        if (utils.containsTag(init.tags, "gameover-title-text")) {
            reg.add(entity, cmp.RecolorText {
                .color = gui_setup.ColorPanelTitle
            });
        }
    }
}

pub fn gui(reg: *ecs.Registry, props: *pr.Properties, change: *game.ScenePropChangeCfg, allocator: std.mem.Allocator) !void {
    var continue_view = reg.view(.{ gcmp.ButtonClicked, cmp.ContinueBtn }, .{});
    var continue_iter = continue_view.entityIterator();
    while (continue_iter.next()) |_| {
        game.destroyAll(gcmp.GameoverScene, reg);

        _ = try game.loadScene(reg, props, change, allocator, initial_scene);
    }

    var recolor_text_view = reg.view(.{ cmp.RecolorText, rcmp.Text }, .{});
    var recolor_text_iter = recolor_text_view.entityIterator();
    while (recolor_text_iter.next()) |entity| {
        const recolor = reg.get(cmp.RecolorText, entity);
        var text = reg.get(rcmp.Text, entity);

        text.color = recolor.color;

        reg.remove(cmp.RecolorText, entity);
    }
}