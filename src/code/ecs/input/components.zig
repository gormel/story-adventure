pub const MousePositionTracker = struct {};
pub const MousePositionInput = struct { x: i32 = 0, y: i32 = 0 };
pub const MousePositionChanged = struct { };

pub const MouseButtonTracker = struct { button: i32 };

pub const KeyInputTracker = struct { key: i32 };

pub const InputPressed = struct {};
pub const InputDown = struct {};
pub const InputReleased = struct {};