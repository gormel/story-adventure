const ecs = @import("zig-ecs");

pub const CreateButton = struct { animated: bool = true };
pub const Button = struct {};
pub const ButtonClicked = struct {};
pub const AnimatedButton = struct {};
pub const ButtonAnimating = struct { delay: f32 };
pub const CreateMessage = struct { parent: ?ecs.Entity, x: f32, y: f32, text: [:0]const u8, free: bool };
pub const MessageDelay = struct { time: f32 };

pub const Hover = struct { entity: ecs.Entity };
pub const Hovered = struct {};

pub const PlayerPropertyChanged = struct { name: []const u8 };
pub const TriggerPlayerPropertyChanged = struct { name: []const u8 };

pub const GameplayScene = struct { name: []const u8 };
pub const NextGameplayScene = struct {};
pub const GameoverScene = struct {};
pub const TemplateInstanceScene = struct {};
pub const SetInputCaptureScene = struct {};
pub const InputCaptureScene = struct {};

pub const GameState = struct {};
pub const GameStateMenu = struct { menu_scene: ?ecs.Entity };
pub const GameStateGameplay = struct { hud_scene: ecs.Entity };

pub const LayoutAxis = enum { Horizontal, Vertical };
pub const LayoutPivot = enum { Begin, Center, End };
pub const LayoutChildren = struct { axis: LayoutAxis, pivot: LayoutPivot, distance: f32 };
pub const LayoutPosition = struct { position: usize };