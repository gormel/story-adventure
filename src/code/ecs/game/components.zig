pub const Button = struct {};
pub const ButtonClicked = struct {};

pub const PlayerPropertyChanged = struct { name: []const u8 };
pub const TriggerPlayerPropertyChanged = struct { name: []const u8 };

pub const GameplayScene = struct { name: []const u8 };
pub const NextGameplayScene = struct {};