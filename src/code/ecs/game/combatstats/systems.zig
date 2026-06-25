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
const itemtemplate = @import("../itemtemplate/itemtemplate.zig");

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

        if (utils.containsTag(init.tags, "combatstats-itemlist-root")) {
            reg.add(entity, cmp.CreateItemList { .scene = init.scene });
        }

        if (utils.containsTag(init.tags, "combatstats-iteminfo-root")) {
            reg.add(entity, cmp.ItemInfoRoot {});
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

        const txt = try std.fmt.allocPrintSentinel(allocator, "{d}", .{ value }, 0);
        reg.add(entity, rcmp.SetTextValue { .text = txt, .free = true });
    }
}

pub fn itemList(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var create_iter = reg.entityIterator(cmp.CreateItemList);
    while (create_iter.next()) |entity| {
        const create = reg.get(cmp.CreateItemList, entity);
        const setup = reg.get(cmp.SceneSetup, create.scene);
        reg.remove(cmp.CreateItemList, entity);
        
        const root_ety = reg.create();
        reg.add(root_ety, rcmp.Position { .x = 5, .y = 5 });
        reg.add(root_ety, rcmp.AttachTo { .target = entity });
        reg.add(root_ety, gcmp.LayoutChildren {
            .axis = gcmp.LayoutAxis.Horizontal,
            .pivot = gcmp.LayoutPivot.Begin,
            .distance = 32 + 5,
        });

        var item_iter = setup.items.iterator();
        while (item_iter.next()) |kv| {
            const item_count = kv.value_ptr.*;
            if (item_count > 0) {
                var root_iter = reg.entityIterator(cmp.ItemInfoRoot);
                const item_ety = try itemtemplate.loadScene(reg, allocator, kv.key_ptr.*, root_iter.next());
                reg.addOrReplace(item_ety, rcmp.AttachTo { .target = root_ety });

                if (item_count > 1) {
                    const text_ety = reg.create();
                    reg.add(text_ety, rcmp.Text {
                        .color = gui_setup.ColorLabelText,
                        .size = gui_setup.SizeText,
                        .free = true,
                        .text = try std.fmt.allocPrintSentinel(allocator, "{d}", .{ item_count }, 0),
                    });
                    reg.add(text_ety, rcmp.Position { .x = 20, .y = 22 });
                    reg.add(text_ety, rcmp.AttachTo { .target = item_ety });
                }
            }
        }
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