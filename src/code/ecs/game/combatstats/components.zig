const ecs = @import("zig-ecs");

pub const SceneSetup = struct { gold: f64, dmgtaken: f64, dmgdealt: f64 };

pub const InitCombatStat = struct { value: f64 };

pub const ContinueButton = struct { scene: ecs.Entity };
pub const Continue = struct {};