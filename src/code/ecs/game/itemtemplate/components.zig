const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");

pub const ItemTemplateScene = struct { infopanel_root: ?ecs.Entity, item: []const u8 };
pub const CreteItemBtn = struct { item: []const u8, infopanel_root: ?ecs.Entity, scene: ecs.Entity };
pub const ItemHover = struct { hover: ecs.Entity };
pub const ItemInfoScene = struct {};

pub const ItemBtn = struct { infopanel_root: ?ecs.Entity, item: []const u8 };