const ecs = @import("zig-ecs");

pub const CreateButton = struct {};
pub const Button = struct {};
pub const ButtonClicked = struct {};
pub const CreateMessage = struct { parent: ?ecs.Entity, x: f32, y: f32, text: [:0]const u8, free: bool };
pub const MessageDelay = struct { time: f32 };

pub const PlayerPropertyChanged = struct { name: []const u8 };
pub const TriggerPlayerPropertyChanged = struct { name: []const u8 };

pub const GameplayScene = struct { name: []const u8 };
pub const NextGameplayScene = struct {};
pub const GameoverScene = struct {};
pub const SetInputCaptureScene = struct {};
pub const InputCaptureScene = struct {};

pub const GameState = struct {};
pub const GameStateMenu = struct { menu_scene: ?ecs.Entity };
pub const GameStateGameplay = struct { hud_scene: ecs.Entity };

pub const LayoutAxis = enum { Horizontal, Vertical };
pub const LayoutPivot = enum { Begin, Center, End };
pub const LayoutChildren = struct { axis: LayoutAxis, pivot: LayoutPivot, distance: f32 };