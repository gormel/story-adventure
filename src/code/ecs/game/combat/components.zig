const std = @import("std");
const ecs = @import("zig-ecs");
const pr = @import("../../../engine/properties.zig");
const combat = @import("combat.zig");

pub const CfgOwner = struct { cfg_json: std.json.Parsed(combat.CombatCfg) };

pub const StrategyList = struct {};
pub const StrategyRoot = struct { locked: ecs.Entity, strategy_id: []const u8, list: ecs.Entity };
pub const StrategyButton = struct { strategy_id: []const u8 };
pub const UpdateStrategyLocked = struct {};

pub const Character = struct { props: pr.Properties, view: ecs.Entity };
pub const Hero = struct {};
pub const Enemy = struct { cfg: combat.EnemyCfg };
pub const CreateCharMsgRoot = struct {};
pub const CharMsgRoot = struct { root: ecs.Entity };

pub const CharacterModifyList = struct { entities: std.ArrayList(ecs.Entity) };
pub const CharacterModify = struct { props: std.json.ArrayHashMap(f64), source_character: ecs.Entity };

pub const Attack = struct { target: ecs.Entity, strategy: []const u8 };
pub const AttackSatate = struct {
    begin: ?ecs.Entity = null,
    target: ecs.Entity,
    time: f64,
    dmg: f64,
    strategy: []const u8,
};
pub const CheckDeath = struct {};

pub const AttackEffect = struct { };

pub const CombatState = struct {};
pub const CombatStatePlayerIdle = struct {};
pub const CombatStatePlayerAttack = struct {};
pub const CombatStateEnemyAttack = struct {};
pub const CombatStateAttackCompleteRequest = struct { source_char: ecs.Entity };
pub const CombatStateAttackFailedRequest = struct {};
pub const CombatStatePlayerDead = struct {};
pub const CombatStateEnemyDead = struct { enemy: ecs.Entity };
pub const CombatStateDeathCompleteRequest = struct {};

pub const Dead = struct {};
pub const DeathTween = struct { character: ecs.Entity };