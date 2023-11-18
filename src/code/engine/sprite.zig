const rl = @import("raylib");

pub const AtlasCfg = struct {
    pub const SpriteCfg = struct {
        name: []u8,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
    };

    tex: []u8,
    sprites: []SpriteCfg,
};

pub const Sprite = struct {
    tex: rl.Texture2D,
    rect: rl.Rectangle,

    pub fn init(tex: rl.Texture2D, rect: rl.Rectangle) *Sprite {
        return Sprite {
            .tex = tex,
            .rect = rect,
        };
    }
};