const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const gamestats = @import("gamestats.zig");

pub const ContinueBtn = struct { owner_scene: ecs.Entity };
pub const SetTitleText = struct { owner_scene: ecs.Entity };

pub const ItemInfoRoot = struct {};

pub const ItemList = struct {};

pub const CreateItemList = struct {};
pub const SetDepthText = struct {};
pub const SetSlainText = struct {};

pub const Continue = struct {};

pub const SceneSetup = struct {
    title: [:0]const u8,
    free_title: bool = false,
};