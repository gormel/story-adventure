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

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");

pub const ParseError = error {
    ExpectedCloseBracket,
};

pub fn initGui(reg: *ecs.Registry) void {
    var init_view = reg.view(.{ scmp.InitGameObject }, .{});
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "iteminfo-icon-root")) {
            reg.add(entity, cmp.AttachIcon { .owner_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "iteminfo-name-text")) {
            reg.add(entity, cmp.SetNameText { .owner_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "iteminfo-description-text")) {
            reg.add(entity, cmp.SetDescriptionText { .owner_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "iteminfo-back-btn")) {
            reg.add(entity, cmp.CloseBtn { .owner_scene = init.scene });
        }
    }
}

pub fn gui(reg: *ecs.Registry, items_cfg: *itm.ItemListCfg, allocator: std.mem.Allocator) !void {
    var name_iter = reg.entityIterator(cmp.SetNameText);
    while (name_iter.next()) |name_ety| {
        const name = reg.get(cmp.SetNameText, name_ety);

        if (reg.tryGet(cmp.SceneSetup, name.owner_scene)) |setup| {
            if (items_cfg.map.get(setup.item)) |item_cfg| {
                reg.addOrReplace(name_ety, rcmp.SetTextValue { .text = item_cfg.name });
            }
        }

        reg.remove(cmp.SetNameText, name_ety);
    }
            
    var desc_iter = reg.entityIterator(cmp.SetDescriptionText);
    while (desc_iter.next()) |desc_ety| {
        const desc = reg.get(cmp.SetDescriptionText, desc_ety);

        if (reg.tryGet(cmp.SceneSetup, desc.owner_scene)) |setup| {
            if (items_cfg.map.get(setup.item)) |item_cfg| {
                const matched_desc = try utils.matchParams(allocator, item_cfg.description, &item_cfg.parameters);

                reg.addOrReplace(desc_ety, rcmp.SetTextValue { .text = matched_desc, .free = true });
            }
        }

        reg.remove(cmp.SetDescriptionText, desc_ety);
    }
    
    var icon_iter = reg.entityIterator(cmp.AttachIcon);
    while (icon_iter.next()) |root_ety| {
        const root = reg.get(cmp.AttachIcon, root_ety);
        if (reg.tryGet(cmp.SceneSetup, root.owner_scene)) |setup| {
            if (items_cfg.map.get(setup.item)) |item_cfg| {
                const icon_ety = reg.create();

                reg.add(icon_ety, rcmp.SpriteResource {
                    .atlas = item_cfg.atlas,
                    .sprite = item_cfg.sprite,
                });
                reg.add(icon_ety, rcmp.AttachTo { .target = root_ety });
            }
        }

        reg.remove(cmp.AttachIcon, root_ety);
    }

    var close_view = reg.view(.{ gcmp.ButtonClicked, cmp.CloseBtn }, .{});
    var close_iter = close_view.entityIterator();
    while (close_iter.next()) |entity| {
        const btn = reg.get(cmp.CloseBtn, entity);
        if (!reg.has(cmp.Close, btn.owner_scene)) {
            reg.add(btn.owner_scene, cmp.Close {});
        }
    }
}