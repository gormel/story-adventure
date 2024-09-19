const std = @import("std");
const ecs = @import("zig-ecs");
const loot = @import("loot.zig");

pub const LootStart = struct { cfg_json: std.json.Parsed(loot.LootCfg) };
pub const Tile = struct {
    fog: ?ecs.Entity = null,
    opener: ?ecs.Entity = null,
    l: ?ecs.Entity = null,
    u: ?ecs.Entity = null,
    r: ?ecs.Entity = null,
    d: ?ecs.Entity = null,
};
pub const RollItem = struct { };
pub const TileFog = struct { entity: ecs.Entity };
pub const TileOpener = struct { entity: ecs.Entity };
pub const TileLoot = struct { entity: ecs.Entity };
pub const Fog = struct { tile: ecs.Entity };
pub const Opener = struct { tile: ecs.Entity, source_tile: ecs.Entity };
pub const Open = struct { free: bool = false };
pub const Visited = struct {};
pub const Loot = struct { tile: ecs.Entity, item_name: []const u8 };