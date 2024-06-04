const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const scmp = @import("../scene/components.zig");
const icmp = @import("../input/components.zig");
const rcmp = @import("../render/components.zig");

pub fn initButton(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject, rcmp.Sprite }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (std.mem.indexOf([]const u8, init.tags, &.{ "button" })) |_| {
            std.debug.print("++++init button {}\n", .{ entity });
        }
    }
}