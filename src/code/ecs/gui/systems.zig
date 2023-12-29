const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const rcmp = @import("../render/components.zig");
const icmp = @import("../input/components.zig");

pub fn button(reg: *ecs.Registry) void {
    var init_view = reg.view(.{ cmp.InitButton }, .{ cmp.Button });
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        const init = init_view.getConst(cmp.InitButton, entity);

        reg.add(entity, cmp.Button { .color = init.color });
        reg.add(entity, rcmp.SolidRect {
            .rect = init.rect,
            .color = init.color,
        });
        reg.add(entity, icmp.MouseButtonTracker { .button = rl.MOUSE_BUTTON_LEFT });
        reg.add(entity, icmp.MouseOverTracker { .rect = init.rect });
        reg.add(entity, icmp.MousePositionTracker {});

        reg.remove(cmp.InitButton, entity);
    }

    var clear_pressed_view = reg.view(.{ cmp.ButtonClick }, .{});
    var clear_pressed_iter = clear_pressed_view.entityIterator();
    while (clear_pressed_iter.next()) |entity| {
        reg.remove(cmp.ButtonClick, entity);
    }

    var pressed_view = reg.view(.{ cmp.Button, icmp.MouseOver, icmp.InputPressed }, .{ rcmp.SetSolidRectColor });
    var pressed_iter = pressed_view.entityIterator();
    while (pressed_iter.next()) |entity| {
        const btn = pressed_view.getConst(cmp.Button, entity);
        reg.add(entity, rcmp.SetSolidRectColor {
            .color = .{ 
                .r = @intFromFloat(@as(f32, @floatFromInt(btn.color.r)) * 0.9),
                .g = @intFromFloat(@as(f32, @floatFromInt(btn.color.g)) * 0.9),
                .b = @intFromFloat(@as(f32, @floatFromInt(btn.color.b)) * 0.9),
                .a = btn.color.a,
            }
        });
    }

    var released_view = reg.view(.{ cmp.Button, icmp.InputReleased }, .{ rcmp.SetSolidRectColor });
    var released_iter = released_view.entityIterator();
    while (released_iter.next()) |entity| {
        const btn = pressed_view.getConst(cmp.Button, entity);
        reg.add(entity, rcmp.SetSolidRectColor {
            .color = .{ .r = btn.color.r, .g = btn.color.g, .b = btn.color.b, .a = btn.color.a }
        });

        if (reg.has(icmp.MouseOver, entity)) {
            reg.add(entity, cmp.ButtonClick {});
        }
    }
}