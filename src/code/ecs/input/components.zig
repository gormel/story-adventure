const rl = @import("raylib");

pub const MousePositionTracker = struct {};
pub const MouseOverTracker = struct { rect: rl.Rectangle };
pub const MouseWheelTracker = struct {};
pub const MousePositionInput = struct { x: i32 = 0, y: i32 = 0 };
pub const MousePositionChanged = struct { };
pub const MouseOver = struct { };

pub const MouseButtonTracker = struct { button: i32 };

pub const KeyInputTracker = struct { key: i32 };

pub const TapTracker = struct { delay: f32 };
pub const TapCandidate = struct { time_remain: f32 };

pub const InputPressed = struct {};
pub const InputDown = struct {};
pub const InputReleased = struct {};
pub const InputTap = struct {};
pub const InputWheel = struct { delta: f32 };
