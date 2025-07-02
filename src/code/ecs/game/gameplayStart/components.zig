const std = @import("std");
const lore = @import("../lore/lore.zig");

pub const Switch = struct {};
pub const CreateLorePanel = struct {};
pub const LorePanel = struct { cfg_json: std.json.Parsed(lore.LoreCfg) };