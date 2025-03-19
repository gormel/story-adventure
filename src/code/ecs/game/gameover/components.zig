const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");

pub const AttachGamestats = struct { owner_scene: ecs.Entity };
pub const GameStatsScene = struct { gameover_scene: ecs.Entity };