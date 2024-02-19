const gcmp = @import("../gui/components.zig");
const rl = @import("raylib");

pub const SceneResource = struct { scene_path: []const u8 };
pub const Scene = struct {};
pub const GameObject = struct {};
pub const Save = struct {};

pub const Sprite = struct { atlas_path: []const u8, sprite: []const u8 };
pub const SpriteLoaded = struct {};
pub const Button = struct { color: rl.Color, rect: rl.Rectangle };
pub const ButtonLoaded = struct {};
pub const LayoutElement = struct { width: f32, height: f32, idx: i32 = -1 };
pub const LayoutElementLoaded = struct {};