const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const shop = @import("shop.zig");

pub const StallSceneSetup = struct { position: usize, shop_scene: ecs.Entity };
pub const StallSceneItems = struct { item_scenes: []ecs.Entity, allocator: std.mem.Allocator };
pub const StallSceneRerollState = struct { price: f64 };
pub const StallSceneRerollCost = struct { text: ecs.Entity };
pub const ItemSceneSetup = struct { item: []const u8, shop_scene: ecs.Entity };
pub const ItemSceneSoldPanel = struct { panel: ecs.Entity };
pub const ItemSceneRoot = struct { root: ecs.Entity };

pub const CreateStall = struct { position: usize, shop_scene: ecs.Entity };
pub const SetStallName = struct { stall_scene: ecs.Entity };
pub const CreateStallItems = struct { stall_scene: ecs.Entity };
pub const AttachItemIcon = struct { item_scene: ecs.Entity };
pub const SetItemPriceText = struct { item_scene: ecs.Entity };
pub const SetStallRerollCost = struct { stall_scene: ecs.Entity };

pub const NextBtn = struct { shop_scene:ecs.Entity };
pub const ItemPopupRoot = struct {};
pub const ItemPopup = struct {};
pub const CfgHolder = struct { cfg: std.json.Parsed(shop.ShopCfg) };
pub const RerollStallBtn = struct { stall_scene: ecs.Entity };
pub const ItemInfoBtn = struct { item: []const u8 };
pub const BuyItemBtn = struct { item_scene: ecs.Entity };

pub const ItemSold = struct {};