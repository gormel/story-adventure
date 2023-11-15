const std = @import("std");
const rl = @import("raylib");

pub const Resource = struct { path: []const u8 };
pub const Sprite = struct { tex: rl.Texture2D, rect: rl.Rectangle };
pub const Position = struct { x: f32, y: f32 };
pub const Rotation = struct { a: f32 };