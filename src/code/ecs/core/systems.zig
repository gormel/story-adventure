const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");

pub fn destroy(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.Destroyed }, .{  });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.destroy(entity);
    }
}