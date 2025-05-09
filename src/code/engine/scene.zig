pub const Position = struct { x: f32, y: f32 };
pub const Image = struct { atlas: []u8, image: []u8 };
pub const Text = struct { text: [:0]u8, size: f32 };

pub const SceneObject = struct {
    position: Position,
    image: ?Image = null,
    text: ?Text = null,
    tags: [][]const u8,
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