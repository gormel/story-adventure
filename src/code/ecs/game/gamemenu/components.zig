const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");

pub const ContinueBtn = struct { owner_scene: ecs.Entity };
pub const ItemsBtn = struct { owner_scene: ecs.Entity };
pub const SettingsBtn = struct {};
pub const ExitBtn = struct {};

pub const ItemsScene = struct {};