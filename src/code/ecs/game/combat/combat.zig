const std = @import("std");

pub const EnemyViewCfg = struct {
    atlas: []const u8,
    idle: []const u8,
};

pub const HeroViewCfg = struct {
    atlas: []const u8,
    idle: []const u8,
};

pub const AttackViewCfg = struct {
    atlas: []const u8,
    effect: []const u8,
};

pub const EnemyCfg = struct {
    name: []const u8,
    strategy: std.json.ArrayHashMap(f64),
    params: std.json.ArrayHashMap(f64),
    view: EnemyViewCfg,
    condition: std.json.ArrayHashMap(f64),
    reward: std.json.ArrayHashMap(f64),
    weight: f64,
};

pub const StrategyViewCfg = struct {
    atlas: []const u8,
    icon: []const u8,
    name: []const u8,
};

pub const StrategyCfg = struct {
    cost: std.json.ArrayHashMap(f64),
    modify: std.json.ArrayHashMap(f64),
    modify_opp: std.json.ArrayHashMap(f64),
    view: StrategyViewCfg,
    condition: std.json.ArrayHashMap(f64),
};

pub const CombatCfg = struct {
    strategy: std.json.ArrayHashMap(StrategyCfg),
    enemy: []EnemyCfg,
    hero_view: HeroViewCfg,
    attack_view: AttackViewCfg,
};