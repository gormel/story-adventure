const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const cmp = @import("components.zig");
const utils = @import("../../engine/utils.zig");
const scmp = @import("../scene/components.zig");
const icmp = @import("../input/components.zig");
const rcmp = @import("../render/components.zig");

pub fn initButton(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject, rcmp.Sprite }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "button")) {
            reg.add(entity, cmp.Button {});
            const sprite = view.getConst(rcmp.Sprite, entity);
            
            reg.add(entity, icmp.MouseOverTracker { .rect = sprite.sprite.rect });
            reg.add(entity, icmp.MouseButtonTracker { .button = rl.MOUSE_BUTTON_LEFT });
        }
    }
}

pub fn button(reg: *ecs.Registry) void {
    var clicked_iter = reg.entityIterator(cmp.ButtonClicked);
    while (clicked_iter.next()) |entity| {
        reg.remove(cmp.ButtonClicked, entity);
    }

    var view = reg.view(.{ icmp.MouseOver, icmp.InputPressed, cmp.Button }, .{ cmp.ButtonClicked });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.add(entity, cmp.ButtonClicked {});
    }
}