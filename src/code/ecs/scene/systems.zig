const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const rs = @import("../../engine/resources.zig");

pub fn loadScene(reg: *ecs.Registry, allocator: std.mem.Allocator, res: *rs.Resources) !void {
    _ = allocator;
    _ = res;
    var view = reg.view(.{ cmp.SceneResource }, .{ cmp.Scene });
    var it = view.entityIterator();
    while (it.next()) |entity| {
        reg.add(entity, cmp.Scene {});

        reg.remove(cmp.SceneResource, entity);
    }
}