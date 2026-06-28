const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const utils = @import("../../../engine/utils.zig");
const pr = @import("../../../engine/properties.zig");
const hud = @import("../hud/hud.zig");
const it = @import("../../../engine/items.zig");
const lore = @import("../lore/lore.zig");

const cmp = @import("components.zig");
const scmp = @import("../../scene/components.zig");
const gcmp = @import("../components.zig");
const rcmp = @import("../../render/components.zig");
const lcmp = @import("../lore/components.zig");
const ccmp = @import("../../core/components.zig");

pub fn initScene(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);

        if (utils.containsTag(init.tags, "chargegameover-init")) {
            reg.add(entity, cmp.InitGameover { .counter = 1 });
        }
    }
}

pub fn logic(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var init_iter = reg.entityIterator(cmp.InitGameover);
    while (init_iter.next()) |entity| {
        var init = reg.get(cmp.InitGameover, entity);
        if (init.counter > 0) {
            init.counter -= 1;
            continue;
        }

        reg.remove(cmp.InitGameover, entity);
        try game.gameOver(reg, allocator);
    }
}