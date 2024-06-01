const rl = @import("raylib");
const sc = @import("../../engine/scene.zig");

pub const SceneResource = struct { scene: sc.Scene };
pub const Scene = struct {};
pub const GameObject = struct { tags: [][]u8 };