const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");

pub const InitButton = struct { color: rl.Color, rect: rl.Rectangle };
pub const Button = struct { color: rl.Color };
pub const ButtonClick = struct {};
