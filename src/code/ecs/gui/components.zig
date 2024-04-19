const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");

pub const InitButton = struct { color: rl.Color, rect: rl.Rectangle };
pub const Button = struct { color: rl.Color };
pub const ButtonClick = struct {};

pub const InitTextInput = struct {
    bg_color: rl.Color,
    text_color: rl.Color,
    rect: rl.Rectangle,
    text: []const u8 = "\x00",
    free_text: bool = false,
};
pub const TextInput = struct { carete_entity: ecs.Entity, label_entity: ecs.Entity, text: []const u8 };
pub const TextInputChanged = struct {};
pub const TextInputSelected = struct {};
pub const TextInputBackspaceTracker = struct { text_entity: ecs.Entity };
pub const FreePrevTextInputValue = struct { to_free: []const u8 };

pub const LayoutDirection = enum(u8) {
    LEFT_RIGHT = 1,
    TOP_DOWN = 2,
    RIGHT_LEFT = 3,
    DOWN_TOP = 4,
};

pub const ScrollDirection = enum(u8) {
    VERTICAL = 1,
    HORIZONTAL = 2,
};

pub const RefreshLinearLayout = struct {};
pub const LinearLayout = struct { dir: LayoutDirection, size: i32 = 0 };
pub const InitLayoutElement = struct { width: f32, height: f32, idx: i32 = -1 };
pub const LayoutElement = struct { width: f32, height: f32, idx: i32 };
pub const Collapsed = struct {};
pub const InitScroll = struct { view_area: rl.Rectangle, dir: ScrollDirection = ScrollDirection.VERTICAL, speed: f32 = 10 };
pub const Scroll = struct { view_area: rl.Rectangle, dir: ScrollDirection, speed: f32 };