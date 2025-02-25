const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const easing = @import("easing.zig");
const sp = @import("../../engine/sprite.zig");

pub const SpriteResource = struct { atlas: []const u8, sprite: []const u8 };
pub const Sprite = struct { sprite: sp.Sprite };

pub const FlipbookResource = struct { atlas: []const u8, flipbook: []const u8 };
pub const Flipbook = struct { flipbook: sp.Flipbook, time: f64 };

pub const ColorComponent = enum {
    R,
    G,
    B,
    A,
    RG,
    RB,
    RA,
    GB,
    GA,
    BA,
    RGB,
    RGA,
    RBA,
    GBA,
    RGBA,
};
pub const Axis = enum { X, Y, XY };
pub const TweenRepeat = enum {
    OnceForward,
    OnceReverse,
    OncePinpong,
    RepeatForward,
    RepeatReverse,
    RepeatPinpong,
};

pub const TweenRotate = struct {};
pub const TweenMove = struct { axis: Axis };
pub const TweenScale = struct { axis: Axis };
pub const TweenColor = struct { component: ColorComponent };
pub const TweenSetup = struct {
    from: f32,
    to: f32,
    duration: f32,
    easing: easing.Easing = easing.Easing.Linear,
    repeat: TweenRepeat = TweenRepeat.OnceForward,
    entity: ecs.Entity,
    remove_source: bool = false,
};
pub const TweenComplete = struct {};
pub const TweenInProgress = struct { duration: f32 };
pub const CancelTween = struct {};

pub const SolidRect = struct { rect: rl.Rectangle, color: rl.Color };
pub const SolidRectOffset = struct { x: f32, y: f32 };
pub const SetSolidRectColor = struct { color: rl.Color };
pub const SolidColorRectUpdated = struct {};

pub const Text = struct { text: [:0]const u8, color: rl.Color, size: f32, free: bool = false };
pub const TextOffset = struct { x: f32, y: f32 };
pub const SetTextColor = struct { color: rl.Color };
pub const TextColorUpdated = struct {};
pub const SetTextValue = struct { text: [:0]const u8, free: bool = false };
pub const TextValueUpdated = struct {};

pub const GameObject = struct {};
pub const Children = struct { children: std.ArrayList(ecs.Entity) };
pub const Parent = struct { entity: ecs.Entity };
pub const AttachTo = struct { target: ?ecs.Entity };
pub const UpdateGlobalTransform = struct {};
pub const GlobalTransformUpdated = struct {};
pub const NotUpdateGlobalTransform = struct {};

pub const Position = struct { x: f32 = 0, y: f32 = 0 };
pub const Scale = struct { x: f32 = 1, y: f32 = 1 };
pub const Rotation = struct { a: f32 = 0 };
pub const Order = struct { order: i32 };
pub const Color = struct { r: u8 = 255, g: u8 = 255, b: u8 = 255, a: u8 = 255 };

pub const GlobalPosition = struct { x: f32, y: f32 };
pub const GlobalScale = struct { x: f32, y: f32 };
pub const GlobalRotation = struct { a: f32 };

pub const Hidden = struct {};
pub const Disabled = struct {};
pub const Scissor = struct { width: f32, height: f32 };

pub const Blink = struct { on_time: f32, off_time: f32 };
pub const BlinkState = struct { time: f32 = 0 };