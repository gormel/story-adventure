const ecs = @import("zig-ecs");
const std = @import("std");

pub const SceneSetup = struct { gold: f64, dmgtaken: f64, dmgdealt: f64, items: std.array_hash_map.String(f64) };

pub const InitCombatStat = struct { value: f64 };

pub const ItemInfoRoot = struct {};
pub const CreateItemList = struct { scene: ecs.Entity };
pub const ContinueButton = struct { scene: ecs.Entity };
pub const Continue = struct {};