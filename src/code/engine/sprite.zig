const rl = @import("raylib");
const std = @import("std");

pub const AtlasCfg = struct {
    pub const SpriteCfg = struct {
        name: []u8,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
    };

    pub const FlipbookCfg = struct {
        name: []u8,
        duration: f64,
        frames: [][]u8,
    };

    tex: []u8,
    sprites: []SpriteCfg,
    animations: []FlipbookCfg,
};

pub const Sprite = struct {
    tex: rl.Texture2D,
    rect: rl.Rectangle,
};

pub const Flipbook = struct {
    tex: rl.Texture2D,
    frames: []rl.Rectangle,
    duration: f64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Flipbook) void {
        self.allocator.free(self.frames);
    }
};