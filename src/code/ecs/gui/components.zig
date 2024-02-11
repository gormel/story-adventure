const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");

pub const InitButton = struct { color: rl.Color, rect: rl.Rectangle };
pub const Button = struct { color: rl.Color };
pub const ButtonClick = struct {};

pub const LayoutDirection = enum(u8) {
    LEFT_RIGHT = 1,
    TOP_DOWN = 2,
    RIGHT_LEFT = 3,
    DOWN_TOP = 4,
};

pub const RefreshLinearLayout = struct {};
pub const LinearLayout = struct { dir: LayoutDirection, size: i32 };
pub const InitLayoutElement = struct { width: f32, height: f32, idx: i32 = -1 };
pub const LayoutElement = struct { width: f32, height: f32, idx: i32 };