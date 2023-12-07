pub const Destroyed = struct {};
pub const DestroyNextFrame = struct {};

pub const Timer = struct { time: f32, initial_time: ?f32 = null };
pub const TimerComplete = struct { time: f32, initial_time: ?f32 = null };
pub const DestroyByTimer = struct {};