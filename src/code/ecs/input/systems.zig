const ecs = @import("zig-ecs");
const rl = @import("raylib");
const cmp = @import("components.zig");
const std = @import("std");
const rcmp = @import("../render/components.zig");
const utils = @import("../../engine/utils.zig");

fn get_scissor(reg: *ecs.Registry, entity: ecs.Entity) ?ecs.Entity {
    if (reg.has(rcmp.Scissor, entity)) {
        return entity;
    }

    if (reg.tryGetConst(rcmp.Parent, entity)) |parent| {
        return get_scissor(reg, parent.entity);
    }

    return null;
}

fn reverse_transform_xy(reg: *ecs.Registry, entity: ecs.Entity, x: *f32, y: *f32) void {
    if (reg.tryGetConst(rcmp.GlobalPosition, entity)) |g_position| {
        x.* -= g_position.x;
        y.* -= g_position.y;
    }

    if (reg.tryGetConst(rcmp.GlobalScale, entity)) |g_scale| {
        x.* /= g_scale.x;
        y.* /= g_scale.y;
    }

    if (reg.tryGetConst(rcmp.GlobalRotation, entity)) |g_rotation| {
        utils.rotate(x, y, -g_rotation.a);
    }
}

fn mouse_over(reg: *ecs.Registry, entity: ecs.Entity) bool {
    const position = reg.getConst(cmp.MousePositionInput, entity);
    const tracker = reg.getConst(cmp.MouseOverTracker, entity);

    var px = @as(f32, @floatFromInt(position.x));
    var py = @as(f32, @floatFromInt(position.y));
    var x = px;
    var y = py;
    reverse_transform_xy(reg, entity, &x, &y);

    if (get_scissor(reg, entity)) |scissor_ety| {
        const scissor = reg.getConst(rcmp.Scissor, scissor_ety);
        var scale_x = @as(f32, 1.0);
        var scale_y = @as(f32, 1.0);
        if (reg.tryGetConst(rcmp.GlobalScale, scissor_ety)) |g_scale| {
            scale_x = g_scale.x;
            scale_y = g_scale.y;
        }

        if (reg.tryGetConst(rcmp.GlobalPosition, scissor_ety)) |g_position| {
            const scissor_rect = rl.Rectangle {
                .x = g_position.x, .y = g_position.y,
                .width = scissor.width * scale_x, .height = scissor.height * scale_y,
            };

            if (!rl.CheckCollisionPointRec(rl.Vector2 { .x = px, .y = py }, scissor_rect)) {
                return false;
            }
        }
    }

    var target_rect = tracker.rect;
    target_rect.x = 0;
    target_rect.y = 0;
    return rl.CheckCollisionPointRec(rl.Vector2 { .x = x, .y = y }, target_rect);
}

pub fn capture(reg: *ecs.Registry, dt: f32) void {
    var pressed_iter = reg.entityIterator(cmp.InputPressed);
    while (pressed_iter.next()) |entity| {
        reg.remove(cmp.InputPressed, entity);
    }

    var released_iter = reg.entityIterator(cmp.InputReleased);
    while (released_iter.next()) |entity| {
        reg.remove(cmp.InputReleased, entity);
    }

    var mpos_iter = reg.entityIterator(cmp.MousePositionChanged);
    while (mpos_iter.next()) |entity| {
        reg.remove(cmp.MousePositionChanged, entity);
    }

    var tap_iter = reg.entityIterator(cmp.InputTap);
    while (tap_iter.next()) |entity| {
        reg.remove(cmp.InputTap, entity);
    }

    var wheel_inp_iter = reg.entityIterator(cmp.InputWheel);
    while (wheel_inp_iter.next()) |entity| {
        reg.remove(cmp.InputWheel, entity);
    }

    const mouse_delta = rl.GetMouseDelta();
    const mouse_pos_x = rl.GetMouseX();
    const mouse_pos_y = rl.GetMouseY();
    const wheel = rl.GetMouseWheelMove();

    var mouse_pos_iter = reg.entityIterator(cmp.MousePositionTracker);
    while (mouse_pos_iter.next()) |entity| {
        var position = reg.getOrAdd(cmp.MousePositionInput, entity);
        position.x = mouse_pos_x;
        position.y = mouse_pos_y;

        if (mouse_delta.x != 0 or mouse_delta.y != 0) {
            reg.add(entity, cmp.MousePositionChanged {});
        }
    }

    var add_over_ms_view = reg.view(.{ cmp.MousePositionInput, cmp.MousePositionChanged, cmp.MouseOverTracker }, .{ cmp.MouseOver });
    var add_over_ms_iter = add_over_ms_view.entityIterator();
    while (add_over_ms_iter.next()) |entity| {
        if (mouse_over(reg, entity)) {
            reg.add(entity, cmp.MouseOver {});
        }
    }

    var add_over_trns_view = reg.view(.{ cmp.MousePositionInput, rcmp.GlobalTransformUpdated, cmp.MouseOverTracker }, .{ cmp.MouseOver });
    var add_over_trns_iter = add_over_trns_view.entityIterator();
    while (add_over_trns_iter.next()) |entity| {
        if (mouse_over(reg, entity)) {
            reg.add(entity, cmp.MouseOver {});
        }
    }

    var rem_over_ms_view = reg.view(.{ cmp.MousePositionInput, cmp.MousePositionChanged, cmp.MouseOverTracker, cmp.MouseOver }, .{});
    var rem_over_ms_iter = rem_over_ms_view.entityIterator();
    while (rem_over_ms_iter.next()) |entity| {
        if (!mouse_over(reg, entity)) {
            reg.remove(cmp.MouseOver, entity);
        }
    }

    var rem_over_trns_view = reg.view(.{ cmp.MousePositionInput, rcmp.GlobalTransformUpdated, cmp.MouseOverTracker, cmp.MouseOver }, .{});
    var rem_over_trns_iter = rem_over_trns_view.entityIterator();
    while (rem_over_trns_iter.next()) |entity| {
        if (!mouse_over(reg, entity)) {
            reg.remove(cmp.MouseOver, entity);
        }
    }

    var mouse_btn_press_view = reg.view(.{ cmp.MouseButtonTracker }, .{ cmp.InputDown });
    var mouse_btn_press_iter = mouse_btn_press_view.entityIterator();
    while (mouse_btn_press_iter.next()) |entity| {
        const tracker = reg.get(cmp.MouseButtonTracker, entity);
        if (rl.IsMouseButtonPressed(tracker.button)) {
            reg.add(entity, cmp.InputPressed {});
            reg.add(entity, cmp.InputDown {});
        }
    }

    var mouse_btn_release_view = reg.view(.{ cmp.MouseButtonTracker, cmp.InputDown }, .{});
    var mouse_btn_release_iter = mouse_btn_release_view.entityIterator();
    while (mouse_btn_release_iter.next()) |entity| {
        const tracker = reg.get(cmp.MouseButtonTracker, entity);
        if (rl.IsMouseButtonReleased(tracker.button)) {
            reg.add(entity, cmp.InputReleased {});
            reg.remove(cmp.InputDown, entity);
        }
    }

    var key_press_view = reg.view(.{ cmp.KeyInputTracker }, .{ cmp.InputDown });
    var key_press_iter = key_press_view.entityIterator();
    while (key_press_iter.next()) |entity| {
        const tracker = reg.get(cmp.KeyInputTracker, entity);
        if (rl.IsKeyPressed(tracker.key)) {
            reg.add(entity, cmp.InputPressed {});
            reg.add(entity, cmp.InputDown {});
        }
    }

    var key_release_view = reg.view(.{ cmp.KeyInputTracker, cmp.InputDown }, .{});
    var key_release_iter = key_release_view.entityIterator();
    while (key_release_iter.next()) |entity| {
        const tracker = reg.get(cmp.KeyInputTracker, entity);
        if (rl.IsKeyReleased(tracker.key)) {
            reg.add(entity, cmp.InputReleased {});
            reg.remove(cmp.InputDown, entity);
        }
    }

    var tap_reg_view = reg.view(.{ cmp.InputPressed, cmp.TapTracker }, .{ cmp.TapCandidate });
    var tap_reg_iter = tap_reg_view.entityIterator();
    while (tap_reg_iter.next()) |entity| {
        const tracker = reg.getConst(cmp.TapTracker, entity);
        reg.add(entity, cmp.TapCandidate { .time_remain = tracker.delay });
    }

    var candidate_iter = reg.entityIterator(cmp.TapCandidate);
    while (candidate_iter.next()) |entity| {
        const candidate = reg.get(cmp.TapCandidate, entity);
        candidate.time_remain -= dt;
        if (candidate.time_remain <= 0) {
            reg.remove(cmp.TapCandidate, entity);
        }
    }

    var set_tap_view = reg.view(.{ cmp.TapTracker, cmp.TapCandidate, cmp.InputReleased }, .{});
    var set_tap_iter = set_tap_view.entityIterator();
    while (set_tap_iter.next()) |entity| {
        reg.remove(cmp.TapCandidate, entity);
        reg.add(entity, cmp.InputTap {});
    }

    var track_wheel_view = reg.view(.{ cmp.MouseWheelTracker }, .{ cmp.InputWheel });
    var track_wheel_iter = track_wheel_view.entityIterator();
    while (track_wheel_iter.next()) |entity| {
        if (@fabs(wheel) > 0) {
            reg.add(entity, cmp.InputWheel {
                .delta = wheel,
            });
        }
    }
}