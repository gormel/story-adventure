const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const game = @import("../utils.zig");
const cmp = @import("components.zig");
const utils = @import("../../../engine/utils.zig");
const scmp = @import("../../scene/components.zig");
const gcmp = @import("../components.zig");

const Properties = @import("../../../engine/parameters.zig").Properties;

pub fn initStartButton(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "button-start-game")) {
            reg.add(entity, cmp.StartGameButton {});
        }
    }
}

pub fn startGame(reg: *ecs.Registry, props: *Properties) !void {
    var view = reg.view(.{ cmp.StartGameButton, gcmp.ButtonClicked }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |_| {
        try props.set("health", 100);

        game.selectNextScene(reg);
    }
}