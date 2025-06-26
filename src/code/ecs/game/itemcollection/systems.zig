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
const itemtemplate = @import("../itemtemplate/itemtemplate.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const iicmp = @import("../iteminfo/components.zig");

const ROW_SIZE = 10;

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

        reg.add(entity, cmp.ItemGrid {});
        reg.add(entity, gcmp.LayoutChildren {
            .axis = .Vertical,
            .distance = 37,
            .pivot = .Begin,
        });

        var col: usize = 0;
        var row: usize = 0;
        var row_ety = reg.create();
        reg.add(row_ety, rcmp.AttachTo { .target = entity });
        reg.add(row_ety, gcmp.LayoutPosition { .position = row });
        reg.add(row_ety, gcmp.LayoutChildren {
            .distance = 37,
            .axis = .Horizontal,
            .pivot = .Begin
        });

        var item_it = itemlist_cfg.map.iterator();
        while (item_it.next()) |item_kv| {
            if (itemprogress_cfg.map.get(item_kv.key_ptr.*)) |progress_prop| {
                if (props.get(progress_prop) > 0) {
                    if (col > ROW_SIZE) {
                        col = 0;
                        row += 1;

                        row_ety = reg.create();
                        reg.add(row_ety, rcmp.AttachTo { .target = entity });
                        reg.add(row_ety, gcmp.LayoutPosition { .position = row });
                        reg.add(row_ety, gcmp.LayoutChildren {
                            .distance = 37,
                            .axis = .Horizontal,
                            .pivot = .Begin
                        });
                    }

                    col += 1;
                    
                    var root_iter = reg.entityIterator(cmp.SmallPopupRoot);
                    const item_ety = try itemtemplate.loadScene(
                        reg, allocator, item_kv.key_ptr.*, root_iter.next());
                    reg.addOrReplace(item_ety, rcmp.AttachTo { .target = row_ety });
                }
            }
        }
    }

    var continue_view = reg.view(.{ cmp.ContinueBtn, gcmp.ButtonClicked }, .{});
    var continue_iter = continue_view.entityIterator();
    while (continue_iter.next()) |entity| {
        const btn = reg.get(cmp.ContinueBtn, entity);

        reg.addOrReplace(btn.owner_scene, cmp.Continue {});
    }
}