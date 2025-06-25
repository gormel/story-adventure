const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const itemcollection = @import("itemcollection.zig");

pub const ContinueBtn = struct { owner_scene: ecs.Entity };
pub const ItemGrid = struct { cfg_json: std.json.Parsed(itemcollection.ItemCollectionCfg) };
pub const SmallPopupRoot = struct {};

pub const CreateItemGrid = struct {};

pub const Continue = struct {};