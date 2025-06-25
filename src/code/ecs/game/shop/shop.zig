const std = @import("std");
const ecs = @import("zig-ecs");
const pr = @import("../../../engine/properties.zig");
const game = @import("../utils.zig");

const cmp = @import("components.zig");
const gcmp = @import("../components.zig");

pub const STALL_SCENE_NAME = "shopstalltemplate";
pub const ITEM_SCENE_NAME = "shopitemtemplate";

pub const StallCfg = struct {
    count: usize,
    group: []const u8,
    name: [:0]const u8,
    position: usize,
};

pub const ShopHoverViewCfg = struct {
    atlas: []const u8,
    image: []const u8,
};

pub const ShopRerollCostCfg = struct {
    property: []const u8,
    base_value: f64,
    multiplyer: f64,
};

pub const ShopCfg = struct {
    stalls: []StallCfg,
    prices: std.json.ArrayHashMap(f64),
    hover_view: ShopHoverViewCfg,
    money_property: []const u8,
    reroll_cost: ShopRerollCostCfg,
};

pub fn loadStallScene(
    reg: *ecs.Registry,
    allocator: std.mem.Allocator,
    position: usize,
    cfg_holder: ecs.Entity
) !ecs.Entity {
    const ety = try game.loadScene(reg, allocator, STALL_SCENE_NAME, .{});
    reg.add(ety, cmp.StallSceneSetup { .position = position, .shop_scene = cfg_holder });
    reg.add(ety, gcmp.TemplateInstanceScene {});
    return ety;
}

pub fn loadItemScene(
    reg: *ecs.Registry,
    allocator: std.mem.Allocator,
    item: []const u8,
    shop_scene: ecs.Entity
) !ecs.Entity {
    const ety = try game.loadScene(reg, allocator, ITEM_SCENE_NAME, .{});
    reg.add(ety, cmp.ItemSceneSetup { .item = item, .shop_scene = shop_scene });
    reg.add(ety, gcmp.TemplateInstanceScene {});
    return ety;
}