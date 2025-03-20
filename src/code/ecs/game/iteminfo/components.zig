const std = @import("std");
const ecs = @import("zig-ecs");

pub const SceneSetup = struct { item: [] const u8 };
pub const Close = struct {};

pub const AttachIcon = struct { owner_scene: ecs.Entity };
pub const SetNameText = struct { owner_scene: ecs.Entity };
pub const SetDescriptionText = struct { owner_scene: ecs.Entity };
pub const CloseBtn = struct { owner_scene: ecs.Entity };