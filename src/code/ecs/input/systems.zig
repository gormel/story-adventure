const ecs = @import("zig-ecs");
const rl = @import("raylib");
const cmp = @import("components.zig");

pub fn capture(reg: *ecs.Registry) void {
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
}