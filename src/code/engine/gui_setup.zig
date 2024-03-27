const std = @import("std");
const rl = @import("raylib");

pub const ColorPanel = rl.Color { .r = 80, .g = 196, .b = 237, .a = 255 };
pub const ColorButton = rl.Color { .r = 51, .g = 58, .b = 115, .a = 255 };
pub const ColorButtonText = rl.Color { .r = 80, .g = 196, .b = 237, .a = 255 };
pub const ColorLabelText = rl.Color { .r = 51, .g = 58, .b = 115, .a = 255 };

pub const SizePanelItem = rl.Rectangle { .x = 0, .y = 0, .width = 200, .height = 20 };
pub const SizeButtonSmall = rl.Rectangle { .x = 0, .y = 0, .width = 20, .height = 20 };

pub const SizeText = 10;

pub fn Margin(comptime left: i32, comptime top: i32, comptime right: i32, comptime bottom: i32) type {
    return struct {
        pub const l = left;
        pub const t = top;
        pub const r = right;
        pub const b = bottom;
        pub const w = left + right;
        pub const h = top + bottom;
    };
}

pub const MarginText = Margin(7, 5, 0, 0);
pub const MarginPanelItem = Margin(0, 0, 0, 5);