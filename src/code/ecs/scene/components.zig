const ecs = @import("zig-ecs");
const rl = @import("raylib");
const sc = @import("../../engine/scene.zig");

pub const SceneResource = struct { scene: sc.Scene };
pub const Scene = struct { };
pub const InitGameObject = struct { tags: [][]const u8, scene: ecs.Entity };
pub const GameObject = struct {};