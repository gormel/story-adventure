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
const main_menu = @import("../mainmenu/mainmenu.zig");
const iteminfo = @import("../iteminfo/iteminfo.zig");
const shop = @import("shop.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const rcmp = @import("../../render/components.zig");
const ccmp = @import("../../core/components.zig");
const gcmp = @import("../components.zig");
const iicmp = @import("../iteminfo/components.zig");

const cfg_text = @embedFile("../../../assets/cfg/scene_customs/shop.json");

const ItemError = error {
    ItemDoesnotExist,
};

pub fn initShop(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
        var init_iter = reg.entityIterator(scmp.InitGameObject);
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "shop-init")) {
            const cfg_json = try std.json.parseFromSlice(shop.ShopCfg, allocator, cfg_text,
                .{ .ignore_unknown_fields = true });
            reg.addOrReplace(init.scene, cmp.CfgHolder { .cfg = cfg_json });
        }

        if (utils.containsTag(init.tags, "shop-itempopup-root")) {
            reg.add(entity, cmp.ItemPopupRoot {});
        }

        if (utils.containsTag(init.tags, "shop-next-btn")) {
            reg.add(entity, cmp.NextBtn { .shop_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "shop-stall-root-1")) {
            reg.add(entity, cmp.CreateStall { .position = 1, .shop_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "shop-stall-root-2")) {
            reg.add(entity, cmp.CreateStall { .position = 2, .shop_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "shop-stall-root-3")) {
            reg.add(entity, cmp.CreateStall { .position = 3, .shop_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "shop-stall-root-4")) {
            reg.add(entity, cmp.CreateStall { .position = 4, .shop_scene = init.scene });
        }
    }
}

pub fn initStall(reg: *ecs.Registry) !void {
        var init_iter = reg.entityIterator(scmp.InitGameObject);
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "shop-stall-name-text")) {
            reg.add(entity, cmp.SetStallName { .stall_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "shop-stall-items-root")) {
            reg.add(entity, cmp.CreateStallItems { .stall_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "shop-stall-refresh-btn")) {
            reg.add(entity, cmp.RerollStallBtn { .stall_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "shop-stall-rerollcost-text")) {
            reg.addOrReplace(init.scene, cmp.StallSceneRerollCost { .text = entity });
            reg.add(entity, cmp.SetStallRerollCost { .stall_scene = init.scene });
        }
    }
}

pub fn initItem(reg: *ecs.Registry) !void {
        var init_iter = reg.entityIterator(scmp.InitGameObject);
    while (init_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "shop-item-item-root")) {
            reg.add(entity, cmp.AttachItemIcon { .item_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "shop-item-price-text")) {
            reg.add(entity, cmp.SetItemPriceText { .item_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "shop-item-buy-btn")) {
            reg.add(entity, cmp.BuyItemBtn { .item_scene = init.scene });
        }

        if (utils.containsTag(init.tags, "shop-item-sold-panel")) {
            reg.add(entity, rcmp.Disabled {});
            reg.addOrReplace(init.scene, cmp.ItemSceneSoldPanel { .panel = entity });
        }
    }
}

fn getStallCfg(cfg: *shop.ShopCfg, position: usize) ?*shop.StallCfg {
    return for (cfg.stalls) |*stall_cfg| {
        if (stall_cfg.position == position) {
            break stall_cfg;
        }
    } else null;
}

pub fn scene(reg: *ecs.Registry) void {
    var next_view = reg.view(.{ gcmp.ButtonClicked, cmp.NextBtn }, .{});
    var next_iter = next_view.entityIterator();
    while (next_iter.next()) |_| {
        game.selectNextScene(reg);
    }
}

pub fn stall(reg: *ecs.Registry, allocator: std.mem.Allocator, items: *itm.Items, rnd: *std.Random, props: *pr.Properties) !void {
    var createscene_iter = reg.entityIterator(cmp.CreateStall);
    while (createscene_iter.next()) |entity| {
        const create = reg.get(cmp.CreateStall, entity);
        const cfg = reg.get(cmp.CfgHolder, create.shop_scene);

        const scene_ety = try shop.loadStallScene(reg, allocator, create.position, create.shop_scene);
        reg.addOrReplace(scene_ety, rcmp.AttachTo { .target = entity });
        reg.add(scene_ety, cmp.StallSceneRerollState { .price = cfg.cfg.value.reroll_cost.base_value });

        reg.remove(cmp.CreateStall, entity);
    }

    var stallname_iter = reg.entityIterator(cmp.SetStallName);
    while (stallname_iter.next()) |entity| {
        const set = reg.get(cmp.SetStallName, entity);
        const setup = reg.get(cmp.StallSceneSetup, set.stall_scene);
        const cfg = reg.get(cmp.CfgHolder, setup.shop_scene);

        if (getStallCfg(&cfg.cfg.value, setup.position)) |stall_cfg| {
            reg.add(entity, rcmp.SetTextValue { .text = stall_cfg.name });
        }

        reg.remove(cmp.SetStallName, entity);
    }

    var items_iter = reg.entityIterator(cmp.CreateStallItems);
    while (items_iter.next()) |entity| {
        const create = reg.get(cmp.CreateStallItems, entity);
        const setup = reg.get(cmp.StallSceneSetup, create.stall_scene);
        const cfg = reg.get(cmp.CfgHolder, setup.shop_scene);

        const row_ety = reg.create();
        reg.add(row_ety, rcmp.AttachTo { .target = entity });
        reg.add(row_ety, gcmp.LayoutChildren { .axis = .Horizontal, .distance = 58, .pivot = .Begin });

        if (getStallCfg(&cfg.cfg.value, setup.position)) |stall_cfg| {
            const item_scenes = try allocator.alloc(ecs.Entity, stall_cfg.count);
            for (0..stall_cfg.count) |i| {
                if (try items.rollGroup(stall_cfg.group, rnd)) |item_id| {
                    const item_root = reg.create();
                    reg.add(item_root, rcmp.AttachTo { .target = row_ety });

                    const item_scene = try shop.loadItemScene(reg, allocator, item_id, setup.shop_scene);
                    reg.addOrReplace(item_scene, rcmp.AttachTo { .target = item_root });
                    reg.add(item_scene, cmp.ItemSceneRoot { .root = item_root });
                    item_scenes[i] = item_scene;
                }
            }

            if (reg.tryGet(cmp.StallSceneItems, create.stall_scene)) |items_ref| {
                items_ref.allocator.free(items_ref.item_scenes);
            }

            reg.addOrReplace(create.stall_scene, cmp.StallSceneItems { 
                .allocator = allocator,
                .item_scenes = item_scenes,
            });
        }

        reg.remove(cmp.CreateStallItems, entity);
    }

    var refresh_view = reg.view(.{ gcmp.ButtonClicked, cmp.RerollStallBtn }, .{});
    var refresh_iter = refresh_view.entityIterator();
    while (refresh_iter.next()) |entity| {
        const btn = reg.get(cmp.RerollStallBtn, entity);
        const setup = reg.get(cmp.StallSceneSetup, btn.stall_scene);
        const cfg = reg.get(cmp.CfgHolder, setup.shop_scene);
        const state = reg.get(cmp.StallSceneRerollState, btn.stall_scene);
        const cost = reg.get(cmp.StallSceneRerollCost, btn.stall_scene);

        if (reg.tryGet(cmp.StallSceneItems, btn.stall_scene)) |items_ref| {
            if (getStallCfg(&cfg.cfg.value, setup.position)) |stall_cfg| {
                if (props.get(cfg.cfg.value.reroll_cost.property) >= state.price) {
                    try props.add(cfg.cfg.value.reroll_cost.property, -state.price);
                    state.price *= cfg.cfg.value.reroll_cost.multiplyer;

                    reg.addOrReplace(cost.text, cmp.SetStallRerollCost { .stall_scene = btn.stall_scene });

                    for (items_ref.item_scenes, 0..) |item_scene, i| {
                        if (reg.valid(item_scene) and !reg.has(cmp.ItemSold, item_scene)) {
                            if (try items.rollGroup(stall_cfg.group, rnd)) |item_id| {
                                const root_ref = reg.get(cmp.ItemSceneRoot, item_scene);
                                reg.add(item_scene, ccmp.Destroyed {});

                                const new_item_scene = try shop.loadItemScene(reg, allocator, item_id, setup.shop_scene);
                                reg.addOrReplace(new_item_scene, rcmp.AttachTo { .target = root_ref.root });
                                reg.add(new_item_scene, cmp.ItemSceneRoot { .root = root_ref.root });

                                items_ref.item_scenes[i] = new_item_scene;
                            }
                        }
                    }
                }
            }
        }
    }

    var rerollcost_iter = reg.entityIterator(cmp.SetStallRerollCost);
    while (rerollcost_iter.next()) |entity| {
        const set = reg.get(cmp.SetStallRerollCost, entity);
        const state = reg.get(cmp.StallSceneRerollState, set.stall_scene);
        const cost = reg.get(cmp.StallSceneRerollCost, set.stall_scene);

        const cost_txt = try std.fmt.allocPrintZ(allocator, "${d}", .{ state.price });
        reg.addOrReplace(cost.text, rcmp.SetTextValue {
            .text = cost_txt,
            .free = true,
        });

        reg.remove(cmp.SetStallRerollCost, entity);
    }
}

pub fn item(reg: *ecs.Registry, allocator: std.mem.Allocator, items: *itm.Items, props: *pr.Properties) !void {
    var icon_iter = reg.entityIterator(cmp.AttachItemIcon);
    while (icon_iter.next()) |entity| {
        const attach = reg.get(cmp.AttachItemIcon, entity);
        const setup = reg.get(cmp.ItemSceneSetup, attach.item_scene);
        const cfg = reg.get(cmp.CfgHolder, setup.shop_scene);
        
        if (items.item_list_cfg.map.get(setup.item)) |item_cfg| {
            const icon_ety = reg.create();
            reg.add(icon_ety, cmp.ItemInfoBtn { .item = setup.item });
            reg.add(icon_ety, gcmp.CreateButton { .animated = false });
            reg.add(icon_ety, rcmp.AttachTo { .target = entity });
            reg.add(icon_ety, rcmp.SpriteResource {
                .atlas = item_cfg.view.atlas,
                .sprite = item_cfg.view.sprite,
            });

            const hover_ety = reg.create();
            reg.add(hover_ety, rcmp.AttachTo { .target = icon_ety });
            reg.add(hover_ety, rcmp.Disabled {});
            reg.add(hover_ety, rcmp.SpriteResource {
                .atlas = cfg.cfg.value.hover_view.atlas,
                .sprite = cfg.cfg.value.hover_view.sprite,
            });

            reg.add(icon_ety, gcmp.Hover { .entity = hover_ety });
        }

        reg.remove(cmp.AttachItemIcon, entity);
    }

    var pricetext_iter = reg.entityIterator(cmp.SetItemPriceText);
    while (pricetext_iter.next()) |entity| {
        const set = reg.get(cmp.SetItemPriceText, entity);
        const setup = reg.get(cmp.ItemSceneSetup, set.item_scene);
        const cfg = reg.get(cmp.CfgHolder, setup.shop_scene);

        if (cfg.cfg.value.prices.map.get(setup.item)) |price| {
            const price_txt = try std.fmt.allocPrintZ(allocator, "${d}", .{ price });
            reg.add(entity, rcmp.SetTextValue { .text = price_txt, .free = true });
        }

        reg.remove(cmp.SetItemPriceText, entity);
    }

    var buy_view = reg.view(.{ gcmp.ButtonClicked, cmp.BuyItemBtn }, .{});
    var buy_iter = buy_view.entityIterator();
    while (buy_iter.next()) |entity| {
        const buy = reg.get(cmp.BuyItemBtn, entity);
        const setup = reg.get(cmp.ItemSceneSetup, buy.item_scene);
        const cfg = reg.get(cmp.CfgHolder, setup.shop_scene);
        
        if (cfg.cfg.value.prices.map.get(setup.item)) |price| {
            const money = props.get(cfg.cfg.value.money_property);
            if (money >= price) {
                try props.add(cfg.cfg.value.money_property, -price);
                if (try items.add(setup.item)) {
                    reg.add(entity, rcmp.Disabled {});
                    reg.add(buy.item_scene, cmp.ItemSold {});

                    if (reg.tryGet(cmp.ItemSceneSoldPanel, buy.item_scene)) |panel_ref| {
                        reg.remove(rcmp.Disabled, panel_ref.panel);
                    }
                } else {
                    return ItemError.ItemDoesnotExist;
                }
            }
        }
    }

    var iteminfo_view = reg.view(.{ gcmp.ButtonClicked, cmp.ItemInfoBtn }, .{});
    var iteminfo_iter = iteminfo_view.entityIterator();
    while (iteminfo_iter.next()) |entity| {
        const btn = reg.get(cmp.ItemInfoBtn, entity);

        var root_iter = reg.entityIterator(cmp.ItemPopupRoot);
        while (root_iter.next()) |root_ety| {
            const scene_ety = try iteminfo.loadScene(reg, allocator, btn.item);
            reg.add(scene_ety, cmp.ItemPopup {});
            reg.addOrReplace(scene_ety, rcmp.AttachTo { .target = root_ety });
        }
    }

    var iteminfocontinue_view = reg.view(.{ iicmp.Close, cmp.ItemPopup }, .{});
    var iteminfocontinue_iter = iteminfocontinue_view.entityIterator();
    while (iteminfocontinue_iter.next()) |entity| {
        if (!reg.has(ccmp.Destroyed, entity)) {
            reg.add(entity, ccmp.Destroyed {});
        }

        reg.remove(iicmp.Close, entity);
    }
}

pub fn free(reg: *ecs.Registry) void {
    var cfg_view = reg.view(.{ ccmp.Destroyed, cmp.CfgHolder }, .{});
    var cfg_iter = cfg_view.entityIterator();
    while (cfg_iter.next()) |entity| {
        const holder = reg.get(cmp.CfgHolder, entity);
        holder.cfg.deinit();

        reg.remove(cmp.CfgHolder, entity);
    }

    var stallitems_view = reg.view(.{ ccmp.Destroyed, cmp.StallSceneItems }, .{});
    var stallitems_iter = stallitems_view.entityIterator();
    while (stallitems_iter.next()) |entity| {
        const items = reg.get(cmp.StallSceneItems, entity);
        items.allocator.free(items.item_scenes);

        reg.remove(cmp.StallSceneItems, entity);
    }
}