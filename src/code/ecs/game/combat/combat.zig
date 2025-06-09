const std = @import("std");

pub const EnemyViewCfg = struct {
    atlas: []const u8,
    idle: []const u8,
};

pub const HeroViewCfg = struct {
    atlas: []const u8,
    idle: []const u8,
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

pub const ImageViewCfg = struct {
    atlas: []const u8,
    image: []const u8,
};

pub const ColorCfg = struct {
    r: f64,
    g: f64,
    b: f64,
    a: ?f64 = null,
};

pub const AttackParticleViewCfg = struct {
    view: ImageViewCfg,
    offset: ?f64 = null,
    scale: ?f64 = null,
    time: ?f64 = null,
    color: ?ColorCfg = null,
};

pub const AttackViewCfg = struct {
    begin: ?ImageViewCfg = null,
    particles: ?[]AttackParticleViewCfg = null,
    end: ?ImageViewCfg = null,
    delay: f64,
};

pub const StrategyViewCfg = struct {
    icon: ImageViewCfg,
    name: [:0]const u8,
    attack: AttackViewCfg,
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
    attack_prop: []const u8,
    armor_prop: []const u8,
    hp_prop: []const u8,
    strategy_locked_icon: ImageViewCfg,
};