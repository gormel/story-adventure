const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const gui_setup = @import("../../../engine/gui_setup.zig");
const condition = @import("../../../engine/condition.zig");
const easing = @import("../../render/easing.zig");
const utils = @import("../../../engine/utils.zig");
const rutils = @import("../../render/utils.zig");
const pr = @import("../../../engine/properties.zig");
const itm = @import("../../../engine/items.zig");
const rr = @import("../../../engine/rollrate.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const lcmp = @import("../lore/components.zig");

pub fn initState(reg: *ecs.Registry) void {
    var init_iter = reg.entityIterator(scmp.InitGameObject);
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "combatstats-button-complete")) {
            reg.add(entity, cmp.ContinueButton { .scene = init.scene });
        }

        if (utils.containsTag(init.tags, "combatstats-title-text")) {
            reg.add(entity, rcmp.SetTextColor { .color = gui_setup.ColorPanelTitle });
        }

        if (utils.containsTag(init.tags, "combatstats-parameter-text")) {
            reg.add(entity, rcmp.SetTextColor { .color = gui_setup.ColorPanelInfo });
        }

        if (utils.containsTag(init.tags, "combatstats-gold-text")) {
            const setup = reg.get(cmp.SceneSetup, init.scene);
            reg.add(entity, cmp.InitCombatStat { .value = setup.gold });
        }

        if (utils.containsTag(init.tags, "combatstats-dmgtaken-text")) {
            const setup = reg.get(cmp.SceneSetup, init.scene);
            reg.add(entity, cmp.InitCombatStat { .value = setup.dmgtaken });
        }

        if (utils.containsTag(init.tags, "combatstats-dmgdealt-text")) {
            const setup = reg.get(cmp.SceneSetup, init.scene);
            reg.add(entity, cmp.InitCombatStat { .value = setup.dmgdealt });
        }
    }
}

pub fn combatStat(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var init_view = reg.view(.{ cmp.InitCombatStat, rcmp.Text }, .{});
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = reg.get(cmp.InitCombatStat, entity);
        const value = init.value;
        reg.remove(cmp.InitCombatStat, entity);

        const txt = try std.fmt.allocPrintZ(allocator, "{d}", .{ value });
        reg.add(entity, rcmp.SetTextValue { .text = txt, .free = true });
    }
}

pub fn complete(reg: *ecs.Registry) void {
    var continue_view = reg.view(.{ cmp.ContinueButton, gcmp.ButtonClicked }, .{});
    var continue_iter = continue_view.entityIterator();
    while (continue_iter.next()) |entity| {
        const btn = reg.get(cmp.ContinueButton, entity);

        reg.addOrReplace(btn.scene, cmp.Continue {});
    }
}