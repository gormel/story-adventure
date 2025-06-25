const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const utils = @import("../../../engine/utils.zig");
const itm = @import("../../../engine/items.zig");
const iteminfo = @import("../iteminfo/iteminfo.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const icmp = @import("../../input/components.zig");
const iicmp = @import("../iteminfo/components.zig");

pub fn initGui(reg: *ecs.Registry) void {
    var init_view = reg.view(.{ scmp.InitGameObject }, .{});
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        
        if (utils.containsTag(init.tags, "itemtemplate-itemicon-root")) {
            const scene = reg.get(cmp.ItemTemplateScene, init.scene);
            reg.add(entity, cmp.CreteItemBtn {
                .infopanel_root = scene.infopanel_root,
                .item = scene.item,
                .scene = init.scene,
            });
        }
        
        if (utils.containsTag(init.tags, "itemtemplate-highlight")) {
            reg.addOrReplace(entity, rcmp.Disabled {});
            reg.addOrReplace(init.scene, cmp.ItemHover { .hover = entity });
        }
    }
}

var idx: i32 = 0;
pub const Debug = struct { idx: i32 };

pub fn updateGui(reg: *ecs.Registry, items: *itm.Items, allocator: std.mem.Allocator) !void {
    var createitembtn_iter = reg.entityIterator(cmp.CreteItemBtn);
    while (createitembtn_iter.next()) |entity| {
        const create = reg.get(cmp.CreteItemBtn, entity);

        if (items.item_list_cfg.map.get(create.item)) |item_cfg| {
            reg.add(entity, rcmp.ImageResource {
                .atlas = item_cfg.view.atlas,
                .image = item_cfg.view.image,
            });
        }

        reg.add(entity, gcmp.CreateButton { .animated = false });
        reg.add(entity, cmp.ItemBtn { .infopanel_root = create.infopanel_root, .item = create.item });

        if (reg.tryGet(cmp.ItemHover, create.scene)) |hover_ref| {
            reg.add(entity, gcmp.Hover { .entity = hover_ref.hover });
        }

        reg.add(entity, Debug { .idx = idx });
        idx += 1;

        reg.remove(cmp.CreteItemBtn, entity);
    }

    var itembtn_view = reg.view(.{ gcmp.ButtonClicked, cmp.ItemBtn }, .{});
    var itembtn_iter = itembtn_view.entityIterator();
    while (itembtn_iter.next()) |entity| {
        const btn = reg.get(cmp.ItemBtn, entity);

        if (btn.infopanel_root) |root_ety| {
            const panel = try iteminfo.loadScene(reg, allocator, btn.item);
            reg.addOrReplace(panel, rcmp.AttachTo { .target = root_ety });
            reg.add(panel, cmp.ItemInfoScene {});
        }
    }

    var closeinfo_view = reg.view(.{ iicmp.Close, cmp.ItemInfoScene }, .{});
    var closeinfo_iter = closeinfo_view.entityIterator();
    while (closeinfo_iter.next()) |entity| {
        reg.addOrReplace(entity, ccmp.Destroyed {});

        reg.remove(iicmp.Close, entity);
    }
}