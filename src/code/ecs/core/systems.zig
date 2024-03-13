const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");

pub fn destroy(reg: *ecs.Registry) void {
    var iter = reg.entityIterator(cmp.Destroyed);
    while (iter.next()) |entity| {
        reg.destroy(entity);
    }
    
    var next_frame_view = reg.view(.{ cmp.DestroyNextFrame }, .{  });
    var next_frame_iter = next_frame_view.entityIterator();
    while (next_frame_iter.next()) |entity| {
        reg.remove(cmp.DestroyNextFrame, entity);
        reg.add(entity, cmp.Destroyed {});
    }
}

pub fn timer(reg: *ecs.Registry, dt: f32) void {
    var clear_iter = reg.entityIterator(cmp.TimerComplete);
    while (clear_iter.next()) |entity| {
        reg.remove(cmp.TimerComplete, entity);
    }

    var iter = reg.entityIterator(cmp.Timer);
    while (iter.next()) |entity| {
        var tmr = reg.get(cmp.Timer, entity);
        if (tmr.initial_time == null) {
            tmr.initial_time = tmr.time;
        }

        tmr.time -= dt;

        if (tmr.time <= 0) {
            reg.add(entity, cmp.TimerComplete {
                .time = tmr.time,
                .initial_time = tmr.initial_time,
            });
            reg.remove(cmp.Timer, entity);
        }
    }
}

pub fn destroy_by_timer(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.DestroyByTimer, cmp.TimerComplete }, .{ cmp.Destroyed });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.add(entity, cmp.Destroyed {});
    }
}