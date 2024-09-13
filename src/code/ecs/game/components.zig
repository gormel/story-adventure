const ecs = @import("zig-ecs");

pub const CreateButton = struct {};
pub const Button = struct {};
pub const ButtonClicked = struct {};

pub const PlayerPropertyChanged = struct { name: []const u8 };
pub const TriggerPlayerPropertyChanged = struct { name: []const u8 };

pub const GameplayScene = struct { name: []const u8 };
pub const NextGameplayScene = struct {};

pub const GameState = struct {};
pub const GameStateMenu = struct { menu_scene: ?ecs.Entity };
pub const GameStateGameplay = struct { hud_scene: ecs.Entity };