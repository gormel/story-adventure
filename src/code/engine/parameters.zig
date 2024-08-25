const std = @import("std");
const ecs = @import("zig-ecs");
const cmp = @import("../ecs/game/components.zig");

pub const Properties = struct {
    const Self = @This();
    reg: *ecs.Registry,
    allocator: std.mem.Allocator,
    map: std.StringArrayHashMap(f64),

    pub fn init(allocator: std.mem.Allocator, reg: *ecs.Registry) Self {
        return .{
            .reg = reg,
            .allocator = allocator,
            .map = std.StringArrayHashMap(f64).init(allocator),
        };
    }

    pub fn get(self: *Self, name: []const u8) f64 {
        return self.map.get(name);
    }

    pub fn set(self: *Self, name: []const u8, value: f64) !void {
        try self.map.put(name, value);
        var entity = self.reg.create();
        self.reg.add(entity, cmp.TriggerPlayerPropertyChanged { .name = name });
    }
};