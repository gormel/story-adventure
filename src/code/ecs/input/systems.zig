const ecs = @import("zig-ecs");
const rl = @import("raylib");
const std = @import("std");
const is = @import("inputstack.zig");
const utils = @import("../../engine/utils.zig");
const rutils = @import("../render/utils.zig");
const game = @import("../game/utils.zig");
const cmp = @import("components.zig");
const rcmp = @import("../render/components.zig");

fn getScissor(reg: *ecs.Registry, entity: ecs.Entity) ?ecs.Entity {
    if (reg.has(rcmp.Scissor, entity)) {
        return entity;
    }

    if (reg.tryGetConst(rcmp.Parent, entity)) |parent| {
        return getScissor(reg, parent.entity);
    }

    return null;
}

fn mouseOver(reg: *ecs.Registry, entity: ecs.Entity) bool {
    const position = reg.getConst(cmp.MousePositionInput, entity);
    const tracker = reg.getConst(cmp.MouseOverTracker, entity);

    const px = @as(f32, @floatFromInt(position.x));
    const py = @as(f32, @floatFromInt(position.y));
    var x = px;
    var y = py;
    rutils.worldToLocalXY(reg, entity, &x, &y);

    if (getScissor(reg, entity)) |scissor_ety| {
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

            if (!rl.checkCollisionPointRec(rl.Vector2.init(px, py), scissor_rect)) {
                return false;
            }
        }
    }

    const target_rect = tracker.rect;
    return rl.checkCollisionPointRec(rl.Vector2.init(x, y), target_rect);
}

fn isInputAllowed(reg: *ecs.Registry, entity: ecs.Entity, input_stack: is.InputStack) bool {
    if (game.queryScene(reg, entity)) |scene_ety| {
        return input_stack.isAccessible(scene_ety);
    }

    return true;
}

pub fn capture(reg: *ecs.Registry, dt: f32, input_stack: is.InputStack) void {
    var pressed_iter = reg.entityIterator(cmp.InputPressed);
    while (pressed_iter.next()) |entity| {
        reg.remove(cmp.InputPressed, entity);
    }

    var released_iter = reg.entityIterator(cmp.InputReleased);
    while (released_iter.next()) |entity| {
        reg.remove(cmp.InputReleased, entity);
    }

    var char_input_iter = reg.entityIterator(cmp.InputChar);
    while (char_input_iter.next()) |entity| {
        reg.remove(cmp.InputChar, entity);
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

    const mouse_delta = rl.getMouseDelta();
    const mouse_pos_x = rl.getMouseX();
    const mouse_pos_y = rl.getMouseY();
    const wheel = rl.getMouseWheelMove();

    var mouse_pos_iter = reg.entityIterator(cmp.MousePositionTracker);
    while (mouse_pos_iter.next()) |entity| {
        if (!isInputAllowed(reg, entity, input_stack)) {
            continue;
        }

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
        if (!isInputAllowed(reg, entity, input_stack)) {
            continue;
        }

        if (mouseOver(reg, entity)) {
            reg.add(entity, cmp.MouseOver {});
        }
    }

    var add_over_trns_view = reg.view(.{ cmp.MousePositionInput, rcmp.GlobalTransformUpdated, cmp.MouseOverTracker }, .{ cmp.MouseOver });
    var add_over_trns_iter = add_over_trns_view.entityIterator();
    while (add_over_trns_iter.next()) |entity| {
        if (!isInputAllowed(reg, entity, input_stack)) {
            continue;
        }

        if (mouseOver(reg, entity)) {
            reg.add(entity, cmp.MouseOver {});
        }
    }

    var rem_over_ms_view = reg.view(.{ cmp.MousePositionInput, cmp.MousePositionChanged, cmp.MouseOverTracker, cmp.MouseOver }, .{});
    var rem_over_ms_iter = rem_over_ms_view.entityIterator();
    while (rem_over_ms_iter.next()) |entity| {
        if (!mouseOver(reg, entity)) {
            reg.remove(cmp.MouseOver, entity);
        }
    }

    var rem_over_trns_view = reg.view(.{ cmp.MousePositionInput, rcmp.GlobalTransformUpdated, cmp.MouseOverTracker, cmp.MouseOver }, .{});
    var rem_over_trns_iter = rem_over_trns_view.entityIterator();
    while (rem_over_trns_iter.next()) |entity| {
        if (!mouseOver(reg, entity)) {
            reg.remove(cmp.MouseOver, entity);
        }
    }

    var mouse_btn_press_view = reg.view(.{ cmp.MouseButtonTracker }, .{ cmp.InputDown });
    var mouse_btn_press_iter = mouse_btn_press_view.entityIterator();
    while (mouse_btn_press_iter.next()) |entity| {
        if (!isInputAllowed(reg, entity, input_stack)) {
            continue;
        }

        const tracker = reg.get(cmp.MouseButtonTracker, entity);
        if (rl.isMouseButtonPressed(tracker.button)) {
            reg.add(entity, cmp.InputPressed {});
            reg.add(entity, cmp.InputDown {});
        }
    }

    var mouse_btn_release_view = reg.view(.{ cmp.MouseButtonTracker, cmp.InputDown }, .{});
    var mouse_btn_release_iter = mouse_btn_release_view.entityIterator();
    while (mouse_btn_release_iter.next()) |entity| {
        if (!isInputAllowed(reg, entity, input_stack)) {
            continue;
        }

        const tracker = reg.get(cmp.MouseButtonTracker, entity);
        if (rl.isMouseButtonReleased(tracker.button)) {
            reg.add(entity, cmp.InputReleased {});
            reg.remove(cmp.InputDown, entity);
        }
    }

    var key_press_view = reg.view(.{ cmp.KeyInputTracker }, .{ cmp.InputDown });
    var key_press_iter = key_press_view.entityIterator();
    while (key_press_iter.next()) |entity| {
        if (!isInputAllowed(reg, entity, input_stack)) {
            continue;
        }

        const tracker = reg.get(cmp.KeyInputTracker, entity);
        if (rl.isKeyPressed(tracker.key)) {
            reg.add(entity, cmp.InputPressed {});
            reg.add(entity, cmp.InputDown {});
        }
    }

    var key_release_view = reg.view(.{ cmp.KeyInputTracker, cmp.InputDown }, .{});
    var key_release_iter = key_release_view.entityIterator();
    while (key_release_iter.next()) |entity| {
        if (!isInputAllowed(reg, entity, input_stack)) {
            continue;
        }

        const tracker = reg.get(cmp.KeyInputTracker, entity);
        if (rl.isKeyReleased(tracker.key)) {
            reg.add(entity, cmp.InputReleased {});
            reg.remove(cmp.InputDown, entity);
        }
    }

    const char = @as(i32, rl.getCharPressed());
    var char_view = reg.view(.{ cmp.CharInputTracker }, .{ cmp.InputChar });
    var char_iter = char_view.entityIterator();
    while (char_iter.next()) |entity| {
        if (!isInputAllowed(reg, entity, input_stack)) {
            continue;
        }

        if (char > 0) {
            reg.add(entity, cmp.InputChar { .char = @intCast(char) });
        }
    }

    var tap_reg_view = reg.view(.{ cmp.InputPressed, cmp.TapTracker }, .{ cmp.TapCandidate });
    var tap_reg_iter = tap_reg_view.entityIterator();
    while (tap_reg_iter.next()) |entity| {
        if (!isInputAllowed(reg, entity, input_stack)) {
            continue;
        }

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
        if (!isInputAllowed(reg, entity, input_stack)) {
            continue;
        }

        if (@abs(wheel) > 0) {
            reg.add(entity, cmp.InputWheel {
                .delta = wheel,
            });
        }
    }
}