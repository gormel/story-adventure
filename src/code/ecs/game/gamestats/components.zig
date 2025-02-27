const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");

pub const ContinueBtn = struct {};
pub const TitleText = struct {};

pub const CreateItemList = struct {};
pub const SetDepthText = struct {};
pub const SetSlainText = struct {};

pub const InitState = struct {
    title: [:0]const u8,
    free_title: bool = false,
};