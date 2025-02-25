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
const sp = @import("../../../engine/sprite.zig");

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

        if (utils.containsTag(init.tags, "gameover-info-name-text")) {
            reg.add(entity, cmp.RecolorText {
                .color = gui_setup.ColorPanelInfo
            });
        }

        if (utils.containsTag(init.tags, "gameover-item-list")) {
            reg.add(entity, cmp.CreateItemList {});
        }

        if (utils.containsTag(init.tags, "gameover-depth-text")) {
            reg.add(entity, cmp.SetDepthText {});
        }

        if (utils.containsTag(init.tags, "gameover-slain-text")) {
            reg.add(entity, cmp.SetSlainText {});
        }
    }
}

pub fn gui(reg: *ecs.Registry, props: *pr.Properties, change: *game.ScenePropChangeCfg, items_cfg: *itm.ItemListCfg, allocator: std.mem.Allocator) !void {
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

    var item_list_iter = reg.entityIterator(cmp.CreateItemList);
    while (item_list_iter.next()) |entity| {
        var it = items_cfg.map.iterator();
        const root_ety = reg.create();
        reg.add(root_ety, rcmp.Position { .x = 5, .y = 5 });
        reg.add(root_ety, rcmp.AttachTo { .target = entity });
        reg.add(root_ety, gcmp.LayoutChildren {
            .axis = gcmp.LayoutAxis.Horizontal,
            .pivot = gcmp.LayoutPivot.Begin,
            .distance = 32 + 5,
        });

        while (it.next()) |kv| {
            const item_count = props.get(kv.key_ptr.*);
            if (item_count > 0) {
                const item_ety = reg.create();
                reg.add(item_ety, rcmp.SpriteResource {
                    .atlas = kv.value_ptr.atlas,
                    .sprite = kv.value_ptr.sprite,
                });
                reg.add(item_ety, rcmp.AttachTo { .target = root_ety });

                if (item_count > 1) {
                    const text_ety = reg.create();
                    reg.add(text_ety, rcmp.Text {
                        .color = gui_setup.ColorLabelText,
                        .size = gui_setup.SizeText,
                        .free = true,
                        .text = try std.fmt.allocPrintZ(allocator, "{d}", .{ item_count }),
                    });
                    reg.add(text_ety, rcmp.Position { .x = 20, .y = 22 });
                    reg.add(text_ety, rcmp.AttachTo { .target = item_ety });
                }
            }
        }

        reg.remove(cmp.CreateItemList, entity);
    }

    var depth_view = reg.view(.{ cmp.SetDepthText, rcmp.Text }, .{});
    var depth_iter = depth_view.entityIterator();
    while (depth_iter.next()) |entity| {
        reg.remove(cmp.SetDepthText, entity);

        const depth = props.get("scene_depth");
        const depthText = try std.fmt.allocPrintZ(allocator, "{d}", .{ depth });
        reg.add(entity, rcmp.SetTextValue {
            .free = true,
            .text = depthText,
        });
    }

    var slain_view = reg.view(.{ cmp.SetSlainText, rcmp.Text }, .{});
    var slain_iter = slain_view.entityIterator();
    while (slain_iter.next()) |entity| {
        reg.remove(cmp.SetSlainText, entity);

        const slain = props.get("kill_count");
        const slainText = try std.fmt.allocPrintZ(allocator, "{d}", .{ slain });
        reg.add(entity, rcmp.SetTextValue {
            .free = true,
            .text = slainText,
        });
    }
}