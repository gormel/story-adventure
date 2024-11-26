const std = @import("std");
const ecs = @import("zig-ecs");
const pr = @import("../../../engine/properties.zig");
const combat = @import("combat.zig");

pub const CfgOwner = struct { cfg_json: std.json.Parsed(combat.CombatCfg) };

pub const StrategyRoot = struct {};
pub const StrategyButton = struct { strategy_id: []const u8 };

pub const Character = struct { props: pr.Properties, view: ecs.Entity };
pub const Hero = struct {};
pub const Enemy = struct { cfg: combat.EnemyCfg };

pub const CharacterModifyList = struct { entities: std.ArrayList(ecs.Entity) };
pub const CharacterModify = struct { props: std.json.ArrayHashMap(f64), source_character: ecs.Entity };

pub const Attack = struct { target: ecs.Entity, strategy: []const u8 };
pub const CheckDeath = struct {};

pub const AttackEffect = struct { cfg: combat.AttackViewCfg, delay: f32, target: ecs.Entity, dmg: f64 };
pub const AttackEffectTween = struct { source_char: ecs.Entity, target_char: ecs.Entity, dmg: f64 };

pub const CombatState = struct {};
pub const CombatStatePlayerIdle = struct {};
pub const CombatStatePlayerAttack = struct {};
pub const CombatStateEnemyAttack = struct {};
pub const CombatStateAttackCompleteRequest = struct { source_char: ecs.Entity };
pub const CombatStatePlayerDead = struct {};
pub const CombatStateEnemyDead = struct { enemy: ecs.Entity };
pub const CombatStateDeathCompleteRequest = struct {};

pub const Dead = struct {};
pub const DeathTween = struct { character: ecs.Entity };