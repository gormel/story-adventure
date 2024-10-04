const std = @import("std");

pub const EnemyCfg = struct {
    name: []const u8,
    strategy: std.json.ArrayHashMap(f64),
    params: std.json.ArrayHashMap(f64),
};

pub const StrategyCfg = struct {
    name: []const u8,
    cost: std.json.ArrayHashMap(f64),
    modify: std.json.ArrayHashMap(f64),
};

pub const CombatCfg = struct {
    strategy: std.json.ArrayHashMap(StrategyCfg),
    enemy: []EnemyCfg,
};