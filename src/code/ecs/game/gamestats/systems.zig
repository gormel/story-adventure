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
const iteminfo = @import("../iteminfo/iteminfo.zig");
const gamestats = @import("gamestats.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const iicmp = @import("../iteminfo/components.zig");

const cfg_text = @embedFile("../../../assets/cfg/scene_customs/gamestats.json");

pub fn initGui(reg: *ecs.Registry) void {
    var iter = reg.entityIterator(scmp.InitGameObject);
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "gamestats-button-continue")) {
            reg.add(entity, cmp.ContinueBtn { .owner_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "gamestats-title-text")) {
            reg.add(entity, rcmp.SetTextColor {
                .color = gui_setup.ColorPanelTitle
            });

            reg.add(entity, cmp.SetTitleText { .owner_scene = init.scene });
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

        if (utils.containsTag(init.tags, "gamestats-iteminfo-root")) {
            reg.add(entity, cmp.ItemInfoRoot {});
        }
    }
}

pub fn gui(reg: *ecs.Registry, props: *pr.Properties, items_cfg: *itm.ItemListCfg, allocator: std.mem.Allocator) !void {

    var title_iter = reg.entityIterator(cmp.SetTitleText);
    while (title_iter.next()) |title_ety| {
        const title = reg.get(cmp.SetTitleText, title_ety);
        if (reg.tryGet(cmp.SceneSetup, title.owner_scene)) |setup| {
            reg.add(title_ety, rcmp.SetTextValue {
                .text = setup.title,
                .free = setup.free_title,
            });
        }

        reg.remove(cmp.SetTitleText, title_ety);
    }

    var item_list_iter = reg.entityIterator(cmp.CreateItemList);
    while (item_list_iter.next()) |entity| {
        
        const cfg_json = try std.json.parseFromSlice(gamestats.GamestatsCfg, allocator, cfg_text, .{});
        reg.add(entity, cmp.ItemList { .cfg_json = cfg_json });

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
                reg.add(item_ety, rcmp.ImageResource {
                    .atlas = kv.value_ptr.view.atlas,
                    .image = kv.value_ptr.view.image,
                });
                reg.add(item_ety, rcmp.AttachTo { .target = root_ety });
                reg.add(item_ety, gcmp.CreateButton { .animated = false });
                reg.add(item_ety, cmp.ItemBtn { .item = kv.key_ptr.* });
                
                const hover_ety = reg.create();
                reg.add(hover_ety, rcmp.ImageResource {
                    .atlas = cfg_json.value.item_hover_view.atlas,
                    .image = cfg_json.value.item_hover_view.image,
                });
                reg.add(hover_ety, rcmp.AttachTo { .target = item_ety });
                reg.add(hover_ety, rcmp.Disabled {});
                reg.add(item_ety, gcmp.Hover { .entity = hover_ety });

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

    var continue_view = reg.view(.{ gcmp.ButtonClicked, cmp.ContinueBtn }, .{});
    var continue_iter = continue_view.entityIterator();
    while (continue_iter.next()) |entity| {
        const btn = reg.get(cmp.ContinueBtn, entity);

        if (!reg.has(cmp.Continue, btn.owner_scene)) {
            reg.add(btn.owner_scene, cmp.Continue {});
        }
    }

    var itembtn_view = reg.view(.{ gcmp.ButtonClicked, cmp.ItemBtn }, .{});
    var itembtn_iter = itembtn_view.entityIterator();
    while (itembtn_iter.next()) |entity| {
        const btn = reg.get(cmp.ItemBtn, entity);

        var root_iter = reg.entityIterator(cmp.ItemInfoRoot);
        while (root_iter.next()) |root_ety| {
            const scene_ety = try iteminfo.loadScene(reg, allocator, btn.item);
            reg.addOrReplace(scene_ety, rcmp.AttachTo { .target = root_ety });
            reg.add(scene_ety, cmp.ItemInfoScene {});
        }
    }

    var iteminfoclose_view = reg.view(.{ iicmp.Close, cmp.ItemInfoScene }, .{});
    var iteminfoclose_iter = iteminfoclose_view.entityIterator();
    while (iteminfoclose_iter.next()) |entity| {
        reg.remove(iicmp.Close, entity);

        if (!reg.has(ccmp.Destroyed, entity)) {
            reg.add(entity, ccmp.Destroyed {});
        }
    }
}

pub fn free(reg: *ecs.Registry) void {
    var itemlist_view = reg.view(.{ cmp.ItemList, ccmp.Destroyed }, .{});
    var itemlist_iter = itemlist_view.entityIterator();
    while (itemlist_iter.next()) |entity| {
        const list = reg.get(cmp.ItemList, entity);

        list.cfg_json.deinit();
    }
}