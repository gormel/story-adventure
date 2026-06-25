const std = @import("std");
const ecs = @import("zig-ecs");

pub const InputStack = struct {
    const Self = @This();
    const EntityStack = std.ArrayList(ecs.Entity);

    stack: EntityStack,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !InputStack {
        return InputStack {
            .stack = try EntityStack.initCapacity(allocator, 4),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.stack.deinit(self.allocator);
    }

    pub fn push(self: *Self, entity: ecs.Entity) !void {
        if (std.mem.indexOfScalar(ecs.Entity, self.stack.items, entity)) |at| {
            _ = self.stack.orderedRemove(at);
        }
        
        try self.stack.append(self.allocator, entity);
    }

    pub fn remove(self: *Self, entity: ecs.Entity) void {
        if (std.mem.indexOfScalar(ecs.Entity, self.stack.items, entity)) |at| {
            _ = self.stack.orderedRemove(at);
        }
    }

    pub fn isAccessible(self: Self, entity: ecs.Entity) bool {
        if (self.stack.getLastOrNull()) |last| {
            return last == entity;
        }

        return true;
    }
};