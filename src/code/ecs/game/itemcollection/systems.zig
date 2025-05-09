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
const itemcollection = @import("itemcollection.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const iicmp = @import("../iteminfo/components.zig");

const cfg_text = @embedFile("../../../assets/cfg/scene_customs/itemcollection.json");

pub fn initGui(reg: *ecs.Registry) void {
    var init_view = reg.view(.{ scmp.InitGameObject }, .{});
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "itemcollection-grid-root")) {
            reg.add(entity, cmp.CreateItemGrid {});
        }

        if (utils.containsTag(init.tags, "itemcollection-continue-btn")) {
            reg.add(entity, cmp.ContinueBtn { .owner_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "itemcollection-smallpopup-root")) {
            reg.add(entity, cmp.SmallPopupRoot {});
        }

        if (utils.containsTag(init.tags, "itemcollection-title-text")) {
            reg.add(entity, rcmp.SetTextColor {
                .color = gui_setup.ColorPanelTitle
            });
        }
    }
}

pub fn gui(
    reg: *ecs.Registry,
    itemlist_cfg: *itm.ItemListCfg,
    itemprogress_cfg: *itm.ItemProgressCfg,
    props: *pr.Properties,
    allocator: std.mem.Allocator
) !void {
    var grid_iter = reg.entityIterator(cmp.CreateItemGrid);
    while (grid_iter.next()) |entity| {
        reg.remove(cmp.CreateItemGrid, entity);

        const cfg_json = try std.json.parseFromSlice(itemcollection.ItemCollectionCfg, allocator, cfg_text, .{});

        reg.add(entity, cmp.ItemGrid { .cfg_json = cfg_json });
        reg.add(entity, gcmp.LayoutChildren {
            .axis = .Vertical,
            .distance = 37,
            .pivot = .Begin,
        });

        //12 cols
        //7 rows
        var col: u32 = 0;
        var row_ety = reg.create();
        reg.add(row_ety, rcmp.AttachTo { .target = entity });
        reg.add(row_ety, gcmp.LayoutChildren {
            .distance = 37,
            .axis = .Horizontal,
            .pivot = .Begin
        });

        var item_it = itemlist_cfg.map.iterator();
        while (item_it.next()) |item_kv| {
            if (itemprogress_cfg.map.get(item_kv.key_ptr.*)) |progress_prop| {
                if (props.get(progress_prop) > 0) {
                    if (col > 11) {
                        col = 0;

                        row_ety = reg.create();
                        reg.add(row_ety, rcmp.AttachTo { .target = entity });
                        reg.add(row_ety, gcmp.LayoutChildren {
                            .distance = 37,
                            .axis = .Horizontal,
                            .pivot = .Begin
                        });
                    }

                    col += 1;

                    const item_ety = reg.create();
                    reg.add(item_ety, rcmp.AttachTo { .target = row_ety });
                    reg.add(item_ety, rcmp.ImageResource {
                        .atlas = item_kv.value_ptr.view.atlas,
                        .image = item_kv.value_ptr.view.image,
                    });
                    reg.add(item_ety, gcmp.CreateButton { .animated = false });
                    reg.add(item_ety, cmp.ItemBtn { .item = item_kv.key_ptr.* });

                    const hover_ety = reg.create();
                    reg.add(hover_ety, rcmp.Disabled {});
                    reg.add(hover_ety, rcmp.AttachTo { .target = item_ety });
                    reg.add(hover_ety, rcmp.ImageResource {
                        .atlas = cfg_json.value.item_hover_view.atlas,
                        .image = cfg_json.value.item_hover_view.image,
                    });
                    reg.add(item_ety, gcmp.Hover { .entity = hover_ety });
                }
            }
        }
    }

    var info_view = reg.view(.{ gcmp.ButtonClicked, cmp.ItemBtn }, .{});
    var info_iter = info_view.entityIterator();
    while (info_iter.next()) |entity| {
        const btn = reg.get(cmp.ItemBtn, entity);

        var root_iter = reg.entityIterator(cmp.SmallPopupRoot);
        while (root_iter.next()) |root_ety| {
            const scene = try iteminfo.loadScene(reg, allocator, btn.item);
            reg.add(scene, cmp.ItemInfoScene {});
            reg.addOrReplace(scene, rcmp.AttachTo { .target = root_ety });
        }
    }

    var closeinfo_view = reg.view(.{ iicmp.Close, cmp.ItemInfoScene }, .{});
    var closeinfo_iter = closeinfo_view.entityIterator();
    while (closeinfo_iter.next()) |entity| {
        reg.remove(iicmp.Close, entity);

        if (!reg.has(ccmp.Destroyed, entity)) {
            reg.add(entity, ccmp.Destroyed {});
        }
    }

    var continue_view = reg.view(.{ cmp.ContinueBtn, gcmp.ButtonClicked }, .{});
    var continue_iter = continue_view.entityIterator();
    while (continue_iter.next()) |entity| {
        const btn = reg.get(cmp.ContinueBtn, entity);

        if (!reg.has(cmp.Continue, btn.owner_scene)) {
            reg.add(btn.owner_scene, cmp.Continue {});
        }
    }
}

pub fn free(reg: *ecs.Registry) void {
    var grid_view = reg.view(.{ cmp.ItemGrid, ccmp.Destroyed }, .{});
    var grid_iter = grid_view.entityIterator();
    while (grid_iter.next()) |entity| {
        const grid = reg.get(cmp.ItemGrid, entity);

        grid.cfg_json.deinit();
    }
}