const std = @import("std");
const ecs = @import("zig-ecs");
const lore = @import("lore.zig");

pub const LoreScene = struct { cfg: lore.LoreCfg };

pub const LoreText = struct { scene: ecs.Entity, block: usize };
pub const LoadLoreBlock = struct { block: usize };
pub const LoreBlockState = struct { last_char: usize, timer: f32, full_text: [:0]const u8 };

pub const RefreshBlockText = struct {};
pub const ForwardLoreBlock = struct {};

pub const Continue = struct {};