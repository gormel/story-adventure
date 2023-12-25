const ecs = @import("zig-ecs");
const rl = @import("raylib");
const cmp = @import("components.zig");
const std = @import("std");
const rcmp = @import("../render/components.zig");
const utils = @import("../../engine/utils.zig");

fn mouse_over(reg: *ecs.Registry, entity: ecs.Entity) bool {
    const position = reg.getConst(cmp.MousePositionInput, entity);
    const tracker = reg.getConst(cmp.MouseOverTracker, entity);

    var x = @as(f32, @floatFromInt(position.x));
    var y = @as(f32, @floatFromInt(position.y));

    if (reg.tryGetConst(rcmp.GlobalPosition, entity)) |g_position| {
        x = x - g_position.x;
        y = y - g_position.y;
    }

    if (reg.tryGetConst(rcmp.GlobalScale, entity)) |g_scale| {
        x = x / g_scale.x;
        y = y / g_scale.y;
    }

    if (reg.tryGetConst(rcmp.GlobalRotation, entity)) |g_rotation| {
        utils.rotate(&x, &y, -g_rotation.a);
    }

    return rl.CheckCollisionPointRec(rl.Vector2 { .x = x, .y = y }, tracker.rect);
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

    const mouse_delta = rl.GetMouseDelta();
    const mouse_pos_x = rl.GetMouseX();
    const mouse_pos_y = rl.GetMouseY();

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
}