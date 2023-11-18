const std = @import("std");
const rl = @import("raylib");
const sp = @import("../../engine/sprite.zig");

pub const Resource = struct { atlas_path: []const u8, sprite: []const u8 };
pub const Sprite = struct { sprite: sp.Sprite };
pub const Position = struct { x: f32, y: f32 };
pub const SpriteOffset = struct { x: f32, y: f32 };
pub const Scale = struct { x: f32, y: f32 };
pub const Rotation = struct { a: f32 };
pub const Children = struct {  };