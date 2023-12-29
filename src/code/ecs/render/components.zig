const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const sp = @import("../../engine/sprite.zig");

pub const SpriteResource = struct { atlas_path: []const u8, sprite: []const u8 };
pub const Sprite = struct { sprite: sp.Sprite };
pub const SpriteOffset = struct { x: f32, y: f32 };

pub const SolidRect = struct { rect: rl.Rectangle, color: rl.Color };
pub const SolidRectOffset = struct { x: f32, y: f32 };
pub const SetSolidRectColor = struct { color: rl.Color };
pub const SolidColorRectUpdated = struct {};

pub const GameObject = struct {};
pub const Children = struct { children: std.ArrayList(ecs.Entity) };
pub const Parent = struct { entity: ecs.Entity };
pub const AttachTo = struct { target: ?ecs.Entity };
pub const UpdateGlobalTransform = struct {};
pub const GlobalTransformUpdated = struct {};
pub const NotUpdateGlobalTransform = struct {};

pub const Position = struct { x: f32, y: f32 };
pub const Scale = struct { x: f32, y: f32 };
pub const Rotation = struct { a: f32 };

pub const GlobalPosition = struct { x: f32, y: f32 };
pub const GlobalScale = struct { x: f32, y: f32 };
pub const GlobalRotation = struct { a: f32 };