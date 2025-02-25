pub const Position = struct { x: f32, y: f32 };
pub const Sprite = struct { atlas: []u8, sprite: []u8 };
pub const Flipbook = struct { atlas: []u8, animation: []u8 };
pub const Text = struct { text: [:0]u8, size: f32 };

pub const SceneObject = struct {
    position: Position,
    sprite: ?Sprite = null,
    flipbook: ?Flipbook = null,
    text: ?Text = null,
    tags: [][]u8,
    children: []SceneObject,
};

pub const Scene = []SceneObject;

pub const RuleParamOperator = enum {
    LE,
    LT,
    EQ,
    GT,
    GE,
};

pub const RuleParam = struct {
    name: []const u8,
    value: f64,
    operator: RuleParamOperator,
};

pub const Rule = struct {
    current_scene: ?[]const u8,
    result_scene: []const u8,
    weight: f64,
    params: []RuleParam,
};

pub const Rules = []Rule;