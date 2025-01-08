const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");

pub const ContinueBtn = struct {};
pub const RecolorText = struct { color: rl.Color };
pub const CreateItemList = struct {};