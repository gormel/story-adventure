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
const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");

pub fn initGui(reg: *ecs.Registry) void {
    var iter = reg.entityIterator(scmp.InitGameObject);
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "gamestats-button-continue")) {
            reg.add(entity, cmp.ContinueBtn {});
        }

        if (utils.containsTag(init.tags, "gamestats-title-text")) {
            reg.add(entity, rcmp.SetTextColor {
                .color = gui_setup.ColorPanelTitle
            });

            reg.add(entity, cmp.TitleText {});
        }

        if (utils.containsTag(init.tags, "gamestats-info-name-text")) {
            reg.add(entity, rcmp.SetTextColor {
                .color = gui_setup.ColorPanelInfo
            });
        }

        if (utils.containsTag(init.tags, "gamestats-item-list")) {
            reg.add(entity, cmp.CreateItemList {});
        }

        if (utils.containsTag(init.tags, "gamestats-depth-text")) {
            reg.add(entity, cmp.SetDepthText {});
        }

        if (utils.containsTag(init.tags, "gamestats-slain-text")) {
            reg.add(entity, cmp.SetSlainText {});
        }
    }
}

pub fn gui(reg: *ecs.Registry, props: *pr.Properties, items_cfg: *itm.ItemListCfg, allocator: std.mem.Allocator) !void {
    var init_state_iter = reg.entityIterator(cmp.InitState);
    while (init_state_iter.next()) |entity| {
        const init = reg.get(cmp.InitState, entity);

        var title_iter = reg.entityIterator(cmp.TitleText);
        while (title_iter.next()) |title_ety| {
            reg.add(title_ety, rcmp.SetTextValue {
                .text = init.title,
                .free = init.free_title,
            });
        }

        reg.remove(cmp.InitState, entity);
    }

    var item_list_iter = reg.entityIterator(cmp.CreateItemList);
    while (item_list_iter.next()) |entity| {
        const root_ety = reg.create();
        reg.add(root_ety, rcmp.Position { .x = 5, .y = 5 });
        reg.add(root_ety, rcmp.AttachTo { .target = entity });
        reg.add(root_ety, gcmp.LayoutChildren {
            .axis = gcmp.LayoutAxis.Horizontal,
            .pivot = gcmp.LayoutPivot.Begin,
            .distance = 32 + 5,
        });

        var it = items_cfg.map.iterator();
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