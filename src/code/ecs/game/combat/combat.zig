const std = @import("std");

pub const EnemyViewCfg = struct {
    atlas: []const u8,
    idle: []const u8,
};

pub const EnemyCfg = struct {
    name: []const u8,
    strategy: std.json.ArrayHashMap(f64),
    params: std.json.ArrayHashMap(f64),
    view: EnemyViewCfg,
    condition: std.json.ArrayHashMap(f64),
};

pub const StrategyViewCfg = struct {
    atlas: []const u8,
    icon: []const u8,
    name: []const u8,
};

pub const StrategyCfg = struct {
    cost: std.json.ArrayHashMap(f64),
    modify: std.json.ArrayHashMap(f64),
    view: StrategyViewCfg,
};

pub const CombatCfg = struct {
    strategy: std.json.ArrayHashMap(StrategyCfg),
    enemy: []EnemyCfg,
};