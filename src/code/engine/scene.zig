pub const Position = struct { x: f32, y: f32 };
pub const Sprite = struct { atlas: []u8, sprite: []u8 };
pub const Text = struct { text: []u8, size: f32 };

pub const SceneObject = struct {
    position: Position,
    sprite: ?Sprite = null,
    text: ?Text = null,
    tags: [][]u8,
    children: []SceneObject,
};

pub const Scene = []SceneObject;