const rl = @import("raylib");

pub const MousePositionTracker = struct {};
pub const MouseOverTracker = struct { rect: rl.Rectangle };
pub const MouseWheelTracker = struct {};
pub const MousePositionInput = struct { x: i32 = 0, y: i32 = 0 };
pub const MousePositionChanged = struct { };
pub const MouseOver = struct { };

pub const MouseButtonTracker = struct { button: rl.MouseButton };

pub const KeyInputTracker = struct { key: rl.KeyboardKey };
pub const CharInputTracker = struct {};

pub const TapTracker = struct { delay: f32 };
pub const TapCandidate = struct { time_remain: f32 };

pub const InputPressed = struct {};
pub const InputDown = struct {};
pub const InputReleased = struct {};
pub const InputTap = struct {};
pub const InputWheel = struct { delta: f32 };
pub const InputChar = struct { char: u8 };
