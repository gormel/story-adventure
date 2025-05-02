const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const assets = @import("assets");
const easing = @import("easing.zig");
const rs = @import("../../engine/resources.zig");
const qu = @import("../../engine/queue.zig");
const utils = @import("../../engine/utils.zig");
const gui_setup = @import("../../engine/gui_setup.zig");
const cmp = @import("components.zig");
const Destroyed = @import("../core/components.zig").Destroyed;
const DestroyNextFrame = @import("../core/components.zig").DestroyNextFrame;

const NoParentGlobalTransform = error { NoParentGlobalTransform };

pub fn initFont(reg: *ecs.Registry, res: *rs.Resources) void {
    const holder_ety = reg.create();

    reg.add(holder_ety, cmp.FontHolder {
        .resources = res,
    });
}

pub fn loadResource(reg: *ecs.Registry, res: *rs.Resources) !void {
    var sprite_view = reg.view(.{ cmp.SpriteResource }, .{ cmp.Sprite });
    var sprite_iter = sprite_view.entityIterator();
    while (sprite_iter.next()) |entity| {
        const res_c = sprite_view.getConst(cmp.SpriteResource, entity);
        reg.add(entity, cmp.Sprite {
            .sprite = try res.loadSprite(res_c.atlas, res_c.sprite)
        });
        reg.remove(cmp.SpriteResource, entity);
    }
    
    var flipbook_view = reg.view(.{ cmp.FlipbookResource }, .{ cmp.Flipbook });
    var flipbook_iter = flipbook_view.entityIterator();
    while (flipbook_iter.next()) |entity| {
        const res_c = flipbook_view.getConst(cmp.FlipbookResource, entity);
        const flipbook = try res.loadFlipbook(res_c.atlas, res_c.flipbook);
        reg.add(entity, cmp.Flipbook {
            .time = flipbook.duration,
            .flipbook = flipbook,
        });
        reg.remove(cmp.FlipbookResource, entity);
    }
}

fn doUpdateGlobalTransform(reg: *ecs.Registry, entity: ecs.Entity) (NoParentGlobalTransform || error {OutOfMemory})!void {
    if (reg.tryGet(cmp.Parent, entity)) |parent| {
        if (
               !reg.has(cmp.GlobalPosition, parent.entity)
            or !reg.has(cmp.GlobalRotation, parent.entity)
            or !reg.has(cmp.GlobalScale, parent.entity)
        ) {
            return error.NoParentGlobalTransform;
        }

        const parent_position = reg.getConst(cmp.GlobalPosition, parent.entity);
        const parent_rotation = reg.getConst(cmp.GlobalRotation, parent.entity);
        const parent_scale = reg.getConst(cmp.GlobalScale, parent.entity);

        if (reg.tryGet(cmp.Position, entity)) |local_position| {
            var rx = local_position.x * parent_scale.x;
            var ry = local_position.y * parent_scale.y;
            utils.rotate(&rx, &ry, parent_rotation.a);
            reg.addOrReplace(entity, cmp.GlobalPosition {
                .x = parent_position.x + rx,
                .y = parent_position.y + ry,
            });
        } else {
            reg.addOrReplace(entity, cmp.GlobalPosition {
                .x = parent_position.x,
                .y = parent_position.y,
            });
        }

        if (reg.tryGet(cmp.Scale, entity)) |local_scale| {
            reg.addOrReplace(entity, cmp.GlobalScale {
                .x = parent_scale.x * local_scale.x,
                .y = parent_scale.y * local_scale.y,
            });
        } else {
            reg.addOrReplace(entity, cmp.GlobalScale {
                .x = parent_scale.x,
                .y = parent_scale.y,
            });
        }

        if (reg.tryGet(cmp.Rotation, entity)) |local_rotation| {
            reg.addOrReplace(entity, cmp.GlobalRotation {
                .a = local_rotation.a + parent_rotation.a
            });
        } else {
            reg.addOrReplace(entity, cmp.GlobalRotation { .a = parent_rotation.a });
        }
        
    } else {
        if (reg.tryGet(cmp.Position, entity)) |local_position| {
            reg.addOrReplace(entity, cmp.GlobalPosition {
                .x = local_position.x,
                .y = local_position.y,
            });
        } else {
            reg.addOrReplace(entity, cmp.GlobalPosition { .x = 0, .y = 0 });
        }

        if (reg.tryGet(cmp.Scale, entity)) |local_scale| {
            reg.addOrReplace(entity, cmp.GlobalScale {
                .x = local_scale.x,
                .y = local_scale.y,
            });
        } else {
            reg.addOrReplace(entity, cmp.GlobalScale { .x = 1, .y = 1 });
        }

        if (reg.tryGet(cmp.Rotation, entity)) |local_rotation| {
            reg.addOrReplace(entity, cmp.GlobalRotation {
                .a = local_rotation.a,
            });
        } else {
            reg.addOrReplace(entity, cmp.GlobalRotation { .a = 0 });
        }
    }

    if (!reg.has(cmp.GlobalTransformUpdated, entity)) {
        reg.add(entity, cmp.GlobalTransformUpdated {});
    }

    if (reg.tryGet(cmp.Children, entity)) |children| {
        for (children.children.items) |child| {
            try doUpdateGlobalTransform(reg, child);
        }
    }
}

fn topoSort(reg: *ecs.Registry, entity: ecs.Entity, out_list: *std.ArrayList(ecs.Entity), allocator: std.mem.Allocator) !void {
    var queue = qu.Queue(ecs.Entity).init(allocator);
    defer queue.deinit();
    if (!reg.has(cmp.Disabled, entity)) {
        try queue.enqueue(entity);
    }
    while (queue.dequeue()) |cur_entity| {
        try out_list.append(cur_entity);
        if (reg.tryGet(cmp.Children, cur_entity)) |children| {
            for (children.children.items) |child_entity| {
                if (!reg.has(cmp.Disabled, child_entity)) {
                    try queue.enqueue(child_entity);
                }
            }
        }
    }
}

fn indexOf(comptime T: type, slice: std.ArrayList(T).Slice, value: T) ?usize {
    return
        for(slice, 0..) |now_value, index| {
            if (now_value == value) {
                break index;
            }
        } else null;
}

fn detachParent(reg: *ecs.Registry, entity: ecs.Entity) !void {
    const parent = reg.getConst(cmp.Parent, entity);
    if (reg.valid(parent.entity)) {
        var parent_children = reg.get(cmp.Children, parent.entity);
        while (indexOf(ecs.Entity, parent_children.children.items, entity))|at_idx| {
            _ = parent_children.children.orderedRemove(at_idx);
        }
    }
    
    reg.remove(cmp.Parent, entity);
}

fn gameObjectRenderOrderLessThan(reg: *ecs.Registry, a: ecs.Entity, b: ecs.Entity) bool {
    const a_order: i32 = if (reg.tryGetConst(cmp.Order, a)) |order| order.order else 0;
    const b_order: i32 = if (reg.tryGetConst(cmp.Order, b)) |order| order.order else 0;
    return a_order < b_order;
}

pub fn attachTo(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var detach_view = reg.view(.{ cmp.AttachTo, cmp.Parent }, .{ });
    var detach_iter = detach_view.entityIterator();
    while (detach_iter.next()) |entity| {
        const attach = detach_view.getConst(cmp.AttachTo, entity);
        const parent = detach_view.getConst(cmp.Parent, entity);
        if (attach.target != parent.entity) {
            try detachParent(reg, entity);
        } else {
            reg.remove(cmp.AttachTo, entity);
        }
    }

    var attach_view = reg.view(.{ cmp.AttachTo }, .{ cmp.Parent });
    var attach_iter = attach_view.entityIterator();
    while (attach_iter.next()) |entity| {
        const attach = attach_view.getConst(cmp.AttachTo, entity);
        if (attach.target) |target_entity| {
            reg.add(entity, cmp.Parent { .entity = target_entity });
            if (reg.tryGet(cmp.Children, target_entity)) |parent_children| {
                try parent_children.children.append(entity);
                std.sort.heap(ecs.Entity, parent_children.children.items,
                    reg, gameObjectRenderOrderLessThan);
            } else {
                var parent_children = cmp.Children {
                    .children = std.ArrayList(ecs.Entity).init(allocator)
                };
                try parent_children.children.append(entity);
                
                reg.add(target_entity, parent_children);
            }
        }
    }

    var update_view = reg.view(.{ cmp.AttachTo }, .{ cmp.UpdateGlobalTransform, cmp.Parent });
    var update_iter = update_view.entityIterator();
    while (update_iter.next()) |entity| {
        reg.add(entity, cmp.UpdateGlobalTransform {});
    }

    var update_middle_view = reg.view(.{ cmp.AttachTo, cmp.Parent }, .{ cmp.UpdateGlobalTransform });
    var update_middle_iter = update_middle_view.entityIterator();
    while (update_middle_iter.next()) |entity| {
        const parent = update_middle_view.getConst(cmp.Parent, entity);
        if (!reg.has(cmp.AttachTo, parent.entity)) {
            reg.add(entity, cmp.UpdateGlobalTransform {});
        }
    }

    var init_view = reg.view(.{ cmp.AttachTo, cmp.Parent }, .{ cmp.GameObject });
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        reg.add(entity, cmp.GameObject {});
    }

    var cleaup_view = reg.view(.{ cmp.AttachTo }, .{ cmp.Parent, });
    var cleaup_iter = cleaup_view.entityIterator();
    while (cleaup_iter.next()) |entity| {
        reg.remove(cmp.AttachTo, entity);
    }
}

pub fn updateGlobalTransform(reg: *ecs.Registry) !void {
    var fltr_upd_view = reg.view(.{ cmp.UpdateGlobalTransform, cmp.Parent }, .{ });
    var fltr_upd_iter = fltr_upd_view.entityIterator();
    while (fltr_upd_iter.next()) |entity| {
        const parent = fltr_upd_view.getConst(cmp.Parent, entity);
        if (reg.has(cmp.UpdateGlobalTransform, parent.entity)) {
            reg.add(entity, cmp.NotUpdateGlobalTransform {});
        }
    }

    var not_upd_view = reg.view(.{ cmp.UpdateGlobalTransform, cmp.NotUpdateGlobalTransform }, .{ });
    var not_upd_iter = not_upd_view.entityIterator();
    while (not_upd_iter.next()) |entity| {
        reg.remove(cmp.UpdateGlobalTransform, entity);
    }

    var cln_upd_view = reg.view(.{ cmp.NotUpdateGlobalTransform }, .{ });
    var cln_upd_iter = cln_upd_view.entityIterator();
    while (cln_upd_iter.next()) |entity| {
        reg.remove(cmp.NotUpdateGlobalTransform, entity);
    }

    var cln_upded_view = reg.view(.{ cmp.GlobalTransformUpdated }, .{ });
    var cln_upded_iter = cln_upded_view.entityIterator();
    while (cln_upded_iter.next()) |entity| {
        reg.remove(cmp.GlobalTransformUpdated, entity);
    }
    
    var updated = false;
    var update_view = reg.view(.{ cmp.UpdateGlobalTransform }, .{ });
    var update_iter = update_view.entityIterator();
    while (update_iter.next()) |entity| {
        try doUpdateGlobalTransform(reg, entity);
        reg.remove(cmp.UpdateGlobalTransform, entity);
        updated = true;
    }
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a * (1 - t) + b * t;
}

const TweenRepeatDirection = enum {
    Forward,
    Reverse,
    Pinpong,
};

fn repeatSetup(repeat: cmp.TweenRepeat) struct { once: bool, dir: TweenRepeatDirection } {
    return switch (repeat) {
        .OnceForward => .{ .once = true, .dir = .Forward },
        .OnceReverse => .{ .once = true, .dir = .Reverse },
        .OncePinpong => .{ .once = true, .dir = .Pinpong },
        .RepeatForward => .{ .once = false, .dir = .Forward },
        .RepeatReverse => .{ .once = false, .dir = .Reverse },
        .RepeatPinpong => .{ .once = false, .dir = .Pinpong },
    };
}

fn abs(x: f32) f32 {
    return if (x < 0) -x else x;
}

fn tweenValue(reg: *ecs.Registry, entity: ecs.Entity) f32 {
    const setup = reg.getConst(cmp.TweenSetup, entity);
    const progress = reg.getConst(cmp.TweenInProgress, entity);

    var t = @min(@max(0, 1 - progress.duration / setup.duration), 1);
    const repeat = repeatSetup(setup.repeat);
    switch (repeat.dir) {
        .Forward => {},
        .Reverse => { t = 1 - t; },
        .Pinpong => { t = 1 - abs((t - 0.5) * 2); },
    }
    return lerp(setup.from, setup.to, easing.getFunc(setup.easing)(t));
}

pub fn tween(reg: *ecs.Registry, dt: f32) void {
    var cancel_view = reg.view(.{ cmp.CancelTween, cmp.TweenSetup }, .{});
    var cancel_iter = cancel_view.entityIterator();
    while (cancel_iter.next()) |entity| {
        reg.remove(cmp.TweenSetup, entity);
        reg.remove(cmp.CancelTween, entity);

        reg.removeIfExists(cmp.TweenInProgress, entity);
        reg.removeIfExists(cmp.TweenComplete, entity);

        if (!reg.has(Destroyed, entity)) {
            reg.add(entity, Destroyed {});
        }
    }

    var complete_view = reg.view(.{ cmp.TweenComplete, cmp.TweenSetup }, .{ Destroyed });
    var complete_iter = complete_view.entityIterator();
    while (complete_iter.next()) |entity| {
        const setup = reg.get(cmp.TweenSetup, entity);
        if (setup.remove_source and reg.valid(setup.entity) and !reg.has(Destroyed, setup.entity)) {
            reg.add(setup.entity, Destroyed {});
        }

        reg.remove(cmp.TweenComplete, entity);
        reg.remove(cmp.TweenSetup, entity);

        reg.add(entity, Destroyed {});
    }

    var start_view = reg.view(.{ cmp.TweenSetup }, .{ cmp.TweenInProgress, cmp.TweenComplete });
    var start_iter = start_view.entityIterator();
    while (start_iter.next()) |entity| {
        const setup = reg.get(cmp.TweenSetup, entity);
        if (!reg.valid(setup.entity)) {
            reg.remove(cmp.TweenSetup, entity);

            if (!reg.has(Destroyed, entity)) {
                reg.add(entity, Destroyed {});
            }
            continue;
        }

        reg.add(entity, cmp.TweenInProgress {
            .duration = setup.duration,
        });
    }

    var view = reg.view(.{ cmp.TweenSetup, cmp.TweenInProgress }, .{ cmp.TweenComplete });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const setup = view.get(cmp.TweenSetup, entity);
        if (!reg.valid(setup.entity)) {
            reg.remove(cmp.TweenSetup, entity);
            reg.remove(cmp.TweenInProgress, entity);

            if (!reg.has(Destroyed, entity)) {
                reg.add(entity, Destroyed {});
            }
            continue;
        }

        var progress = view.get(cmp.TweenInProgress, entity);
        progress.duration -= dt;
    }

    var move_view = reg.view(.{ cmp.TweenSetup, cmp.TweenMove, cmp.TweenInProgress }, .{});
    var move_iter = move_view.entityIterator();
    while (move_iter.next()) |entity| {
        const setup = reg.getConst(cmp.TweenSetup, entity);
        const move = reg.getConst(cmp.TweenMove, entity);

        const value = tweenValue(reg, entity);

        var pos = reg.getOrAdd(cmp.Position, setup.entity);
        switch (move.axis) {
            .X => { pos.x = value; },
            .Y => { pos.y = value; },
            .XY => { pos.x = value; pos.y = value; },
        }

        if (!reg.has(cmp.UpdateGlobalTransform, setup.entity)) {
            reg.add(setup.entity, cmp.UpdateGlobalTransform {});
        }
    }

    var scale_view = reg.view(.{ cmp.TweenSetup, cmp.TweenScale, cmp.TweenInProgress }, .{});
    var scale_iter = scale_view.entityIterator();
    while (scale_iter.next()) |entity| {
        const setup = reg.getConst(cmp.TweenSetup, entity);
        const scale = reg.getConst(cmp.TweenScale, entity);

        const value = tweenValue(reg, entity);

        var scaleValue = reg.getOrAdd(cmp.Scale, setup.entity);
        switch (scale.axis) {
            .X => { scaleValue.x = value; },
            .Y => { scaleValue.y = value; },
            .XY => { scaleValue.x = value; scaleValue.y = value; },
        }

        if (!reg.has(cmp.UpdateGlobalTransform, setup.entity)) {
            reg.add(setup.entity, cmp.UpdateGlobalTransform {});
        }
    }

    var rotate_view = reg.view(.{ cmp.TweenSetup, cmp.TweenRotate, cmp.TweenInProgress }, .{});
    var rotate_iter = rotate_view.entityIterator();
    while (rotate_iter.next()) |entity| {
        const setup = reg.getConst(cmp.TweenSetup, entity);

        const value = tweenValue(reg, entity);

        reg.addOrReplace(setup.entity, cmp.Rotation { .a = value });

        if (!reg.has(cmp.UpdateGlobalTransform, setup.entity)) {
            reg.add(setup.entity, cmp.UpdateGlobalTransform {});
        }
    }

    var color_view = reg.view(.{ cmp.TweenSetup, cmp.TweenColor, cmp.TweenInProgress }, .{});
    var color_iter = color_view.entityIterator();
    while (color_iter.next()) |entity| {
        const setup = reg.getConst(cmp.TweenSetup, entity);
        const color = reg.getConst(cmp.TweenColor, entity);

        const value = tweenValue(reg, entity);

        var colorValue = reg.getOrAdd(cmp.Color, setup.entity);
        switch (color.component) {
            .R => { colorValue.r = @intFromFloat(value); },
            .G => { colorValue.g = @intFromFloat(value); },
            .B => { colorValue.b = @intFromFloat(value); },
            .A => { colorValue.a = @intFromFloat(value); },
            .RG => {
                colorValue.r = @intFromFloat(value);
                colorValue.g = @intFromFloat(value);
            },
            .RB => {
                colorValue.r = @intFromFloat(value);
                colorValue.b = @intFromFloat(value);
            },
            .RA => {
                colorValue.r = @intFromFloat(value);
                colorValue.a = @intFromFloat(value);
            },
            .GB => {
                colorValue.g = @intFromFloat(value);
                colorValue.b = @intFromFloat(value);
            },
            .GA => {
                colorValue.g = @intFromFloat(value);
                colorValue.a = @intFromFloat(value);
            },
            .BA => {
                colorValue.b = @intFromFloat(value);
                colorValue.a = @intFromFloat(value);
            },
            .RGB => {
                colorValue.r = @intFromFloat(value);
                colorValue.g = @intFromFloat(value);
                colorValue.b = @intFromFloat(value);
            },
            .RGA => {
                colorValue.r = @intFromFloat(value);
                colorValue.g = @intFromFloat(value);
                colorValue.a = @intFromFloat(value);
            },
            .RBA => {
                colorValue.r = @intFromFloat(value);
                colorValue.b = @intFromFloat(value);
                colorValue.a = @intFromFloat(value);
            },
            .GBA => {
                colorValue.g = @intFromFloat(value);
                colorValue.b = @intFromFloat(value);
                colorValue.a = @intFromFloat(value);
            },
            .RGBA => {
                colorValue.r = @intFromFloat(value);
                colorValue.g = @intFromFloat(value);
                colorValue.b = @intFromFloat(value);
                colorValue.a = @intFromFloat(value);
            },
        }

        if (!reg.has(cmp.UpdateGlobalTransform, setup.entity)) {
            reg.add(setup.entity, cmp.UpdateGlobalTransform {});
        }
    }

    
    var complate_view = reg.view(.{ cmp.TweenSetup, cmp.TweenInProgress }, .{ cmp.TweenComplete });
    var complate_iter = complate_view.entityIterator();
    while (complate_iter.next()) |entity| {
        const setup = view.get(cmp.TweenSetup, entity);
        var progress = view.get(cmp.TweenInProgress, entity);

        if (progress.duration <= 0) {
            const repeat = repeatSetup(setup.repeat);
            if (repeat.once) {
                reg.remove(cmp.TweenInProgress, entity);
                reg.add(entity, cmp.TweenComplete {});
            } else {
                progress.duration = setup.duration;
            }
        }
    }
}

pub fn blink(reg: *ecs.Registry, dt: f32) void {
    var cleanup_view = reg.view(.{ cmp.BlinkState }, .{ cmp.Blink });
    var cleanup_iter = cleanup_view.entityIterator();
    while (cleanup_iter.next()) |entity| {
        reg.remove(cmp.BlinkState, entity);
    }

    var init_view = reg.view(.{ cmp.Blink }, .{ cmp.BlinkState });
    var init_iter = init_view.entityIterator();
    while (init_iter.next()) |entity| {
        reg.add(entity, cmp.BlinkState { .time = 0 });
    }

    var show_view = reg.view(.{ cmp.Blink, cmp.BlinkState, cmp.Hidden }, .{});
    var show_iter = show_view.entityIterator();
    while (show_iter.next()) |entity| {
        const setup = show_view.getConst(cmp.Blink, entity);
        var state = show_view.get(cmp.BlinkState, entity);
        state.time += dt;

        if (state.time > setup.off_time) {
            reg.remove(cmp.Hidden, entity);
            state.time = 0;
        }
    }

    var hide_view = reg.view(.{ cmp.Blink, cmp.BlinkState }, .{ cmp.Hidden });
    var hide_iter = hide_view.entityIterator();
    while (hide_iter.next()) |entity| {
        const setup = show_view.getConst(cmp.Blink, entity);
        var state = show_view.get(cmp.BlinkState, entity);
        state.time += dt;

        if (state.time > setup.on_time) {
            reg.add(entity, cmp.Hidden {});
            state.time = 0;
        }
    }
}

pub fn updateFlipbook(reg: *ecs.Registry, dt: f64) void {
    var upd_view = reg.view(.{ cmp.Flipbook }, .{ cmp.FlipbookFrozen });
    var upd_iter = upd_view.entityIterator();
    while (upd_iter.next()) |entity| {
        const flipbook = reg.get(cmp.Flipbook, entity);
        flipbook.time -= dt;
        if (flipbook.time <= 0) {
            if (reg.tryGet(cmp.FlipbookSetup, entity)) |setup| {
                switch (setup.repeat) {
                    .OnceFreeze => {
                        flipbook.time = 0;
                        reg.add(entity, cmp.FlipbookFrozen {});
                    },
                    .OnceRemove => { reg.add(entity, Destroyed {}); },
                    .Repeat => { flipbook.time = flipbook.flipbook.duration; },
                }
            } else {
                flipbook.time = flipbook.flipbook.duration;
            }
        }
    }
}

pub fn freeFlipbook(reg: *ecs.Registry) void {
    var view = reg.view(.{ Destroyed, cmp.Flipbook }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var flipbook = reg.get(cmp.Flipbook, entity);
        flipbook.flipbook.deinit();

        reg.remove(cmp.Flipbook, entity);
    }
}

pub fn destroyChildren(reg: *ecs.Registry) !void {
    var parent_view = reg.view(.{ Destroyed, cmp.Parent }, .{ });
    var parent_iter = parent_view.entityIterator();
    while (parent_iter.next()) |entity| {
        try detachParent(reg, entity);
    }
    
    var children_view = reg.view(.{ Destroyed, cmp.Children }, .{ });
    var children_iter = children_view.entityIterator();
    while (children_iter.next()) |entity| {
        var children = children_view.get(cmp.Children, entity);
        for (children.children.items) |child_entity| {
            reg.add(child_entity, DestroyNextFrame {});
            reg.removeIfExists(cmp.Parent, child_entity);
        }
        children.children.deinit();
        reg.remove(cmp.Children, entity);
    }
}

pub fn setSolidRectColor(reg: *ecs.Registry) void {
    var clear_view = reg.view(.{ cmp.SolidColorRectUpdated }, .{});
    var clear_iter = clear_view.entityIterator();
    while (clear_iter.next()) |entity| {
        reg.remove(cmp.SolidColorRectUpdated, entity);
    }

    var view = reg.view(.{ cmp.SetSolidRectColor, cmp.SolidRect }, .{ cmp.SolidColorRectUpdated });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
       var rect = view.get(cmp.SolidRect, entity);
       const set = view.getConst(cmp.SetSolidRectColor, entity);

       rect.color = set.color;
       reg.remove(cmp.SetSolidRectColor, entity);
       reg.add(entity, cmp.SolidColorRectUpdated {});
    }
}

pub fn setTextParams(reg: *ecs.Registry, allocator: std.mem.Allocator) void {
    var clear_color_view = reg.view(.{ cmp.TextColorUpdated }, .{});
    var clear_color_iter = clear_color_view.entityIterator();
    while (clear_color_iter.next()) |entity| {
        reg.remove(cmp.TextColorUpdated, entity);
    }

    var clear_value_view = reg.view(.{ cmp.TextValueUpdated }, .{});
    var clear_value_iter = clear_value_view.entityIterator();
    while (clear_value_iter.next()) |entity| {
        reg.remove(cmp.TextValueUpdated, entity);
    }

    var color_view = reg.view(.{ cmp.SetTextColor, cmp.Text }, .{ cmp.TextColorUpdated });
    var color_iter = color_view.entityIterator();
    while (color_iter.next()) |entity| {
        var text = color_view.get(cmp.Text, entity);
        const set = color_view.getConst(cmp.SetTextColor, entity);

        text.color = set.color;
        reg.remove(cmp.SetTextColor, entity);
        reg.add(entity, cmp.TextColorUpdated {});
    }

    var value_view = reg.view(.{ cmp.SetTextValue, cmp.Text }, .{ cmp.TextValueUpdated });
    var value_iter = value_view.entityIterator();
    while (value_iter.next()) |entity| {
        var text = value_view.get(cmp.Text, entity);
        const set = value_view.getConst(cmp.SetTextValue, entity);

        if (text.free) {
            allocator.free(text.text);
        }

        text.text = set.text;
        text.free = set.free;
        reg.remove(cmp.SetTextValue, entity);
        reg.add(entity, cmp.TextValueUpdated {});
    }

}

fn renderSprite(reg: *ecs.Registry, entity: ecs.Entity) !void {
    const sprite = reg.getConst(cmp.Sprite, entity);
    const pos = reg.getConst(cmp.GlobalPosition, entity);
    const rot = reg.getConst(cmp.GlobalRotation, entity);
    const scale = reg.getConst(cmp.GlobalScale, entity);

    const origin = rl.Vector2 { .x = 0, .y = 0 };

    var color = rl.Color.white;
    if (reg.tryGetConst(cmp.Color, entity)) |color_component| {
        color.r = color_component.r;
        color.g = color_component.g;
        color.b = color_component.b;
        color.a = color_component.a;
    }

    const target_rect = rl.Rectangle {
        .x = pos.x, .y = pos.y,
        .width = sprite.sprite.rect.width * scale.x,
        .height = sprite.sprite.rect.height * scale.y
    };
    rl.drawTexturePro(sprite.sprite.tex, sprite.sprite.rect, target_rect, origin, rot.a, color);
}

fn renderFlipbook(reg: *ecs.Registry, entity: ecs.Entity) !void {
    const flipbook = reg.getConst(cmp.Flipbook, entity);
    const pos = reg.getConst(cmp.GlobalPosition, entity);
    const rot = reg.getConst(cmp.GlobalRotation, entity);
    const scale = reg.getConst(cmp.GlobalScale, entity);

    const origin = rl.Vector2 { .x = 0, .y = 0 };
    const flen = @as(f64, @floatFromInt(flipbook.flipbook.frames.len));
    var idx = @as(usize, @intFromFloat(std.math.floor((flipbook.flipbook.duration - flipbook.time) * flen / flipbook.flipbook.duration)));
    idx = @min(flipbook.flipbook.frames.len - 1, idx);
    const frame = flipbook.flipbook.frames[idx];

    var color = rl.Color.white;
    if (reg.tryGetConst(cmp.Color, entity)) |colorComponent| {
        color.r = colorComponent.r;
        color.g = colorComponent.g;
        color.b = colorComponent.b;
        color.a = colorComponent.a;
    }

    const target_rect = rl.Rectangle {
        .x = pos.x, .y = pos.y,
        .width = frame.width * scale.x,
        .height = frame.height * scale.y
    };
    rl.drawTexturePro(flipbook.flipbook.tex, frame, target_rect, origin, rot.a, color);
}

fn renderSolidRect(reg: *ecs.Registry, entity: ecs.Entity) !void {
    const rect = reg.getConst(cmp.SolidRect, entity);
    const pos = reg.getConst(cmp.GlobalPosition, entity);
    const rot = reg.getConst(cmp.GlobalRotation, entity);
    const scale = reg.getConst(cmp.GlobalScale, entity);

    var origin = rl.Vector2 { .x = 0, .y = 0 };
    if (reg.tryGetConst(cmp.SolidRectOffset, entity)) |offset| {
        origin.x = offset.x;
        origin.y = offset.y;
    }

    const target_rect = rl.Rectangle {
        .x = pos.x, .y = pos.y,
        .width = rect.rect.width * scale.x,
        .height = rect.rect.height * scale.y
    };

    var color = rect.color;
    if (reg.tryGetConst(cmp.Color, entity)) |colorComponent| {
        color.r = @intFromFloat(@as(f32, @floatFromInt(color.r)) * @as(f32, @floatFromInt(colorComponent.r)) / 255);
        color.g = @intFromFloat(@as(f32, @floatFromInt(color.g)) * @as(f32, @floatFromInt(colorComponent.g)) / 255);
        color.b = @intFromFloat(@as(f32, @floatFromInt(color.b)) * @as(f32, @floatFromInt(colorComponent.b)) / 255);
        color.a = @intFromFloat(@as(f32, @floatFromInt(color.a)) * @as(f32, @floatFromInt(colorComponent.a)) / 255);
    }

    rl.drawRectanglePro(target_rect, origin, rot.a, color);
}

fn renderText(reg: *ecs.Registry, entity: ecs.Entity) !void {
    const text = reg.getConst(cmp.Text, entity);
    const pos = reg.getConst(cmp.GlobalPosition, entity);
    const rot = reg.getConst(cmp.GlobalRotation, entity);
    //const scale = reg.getConst(cmp.GlobalScale, entity);

    var origin = rl.Vector2 { .x = 0, .y = 0 };
    if (reg.tryGetConst(cmp.TextOffset, entity)) |offset| {
        origin.x = offset.x;
        origin.y = offset.y;
    }

    var color = text.color;
    if (reg.tryGetConst(cmp.Color, entity)) |colorComponent| {
        color.r = @intFromFloat(@as(f32, @floatFromInt(color.r)) * @as(f32, @floatFromInt(colorComponent.r)) / 255);
        color.g = @intFromFloat(@as(f32, @floatFromInt(color.g)) * @as(f32, @floatFromInt(colorComponent.g)) / 255);
        color.b = @intFromFloat(@as(f32, @floatFromInt(color.b)) * @as(f32, @floatFromInt(colorComponent.b)) / 255);
        color.a = @intFromFloat(@as(f32, @floatFromInt(color.a)) * @as(f32, @floatFromInt(colorComponent.a)) / 255);
    }

    const position = rl.Vector2 { .x = pos.x, .y = pos.y };

    if (text.text.len > 0) {
        var font = try rl.getFontDefault();

        var font_iter = reg.entityIterator(cmp.FontHolder);
        while (font_iter.next()) |font_ety| {
            const holder = reg.get(cmp.FontHolder, font_ety);
            const text_size = @as(i32, @intFromFloat(text.size));
            font = try holder.resources.loadFont(gui_setup.FontDefault, text_size);
            break;
        }
        
        rl.drawTextPro(font, text.text, position, origin, rot.a, text.size, 3, color);
    }
}

const render_fns = .{
    .{ .cmp = cmp.Sprite, .func = renderSprite },
    .{ .cmp = cmp.Flipbook, .func = renderFlipbook },
    .{ .cmp = cmp.SolidRect, .func = renderSolidRect },
    .{ .cmp = cmp.Text, .func = renderText },
};

fn renderObjects(reg: *ecs.Registry, entity: ecs.Entity, parent_scissor_rect: ?rl.Rectangle) !void {
    if (reg.has(cmp.Disabled, entity)) {
        return;
    }
    
    if (reg.has(Destroyed, entity)) {
        return;
    }

    if (!reg.has(cmp.Hidden, entity)) {
        inline for (render_fns) |map| {
            if (reg.has(map.cmp, entity)) {
                try map.func(reg, entity);
            }
        }
    }

    var shold_end_scissor = false;
    var scissor_rect: ?rl.Rectangle = parent_scissor_rect;
    if (reg.tryGetConst(cmp.Scissor, entity)) |scissor| {
        const pos = reg.getConst(cmp.GlobalPosition, entity);
        const scale = reg.getConst(cmp.GlobalScale, entity);

        scissor_rect = rl.Rectangle {
            .x = pos.x, .y = pos.y, 
            .width = scissor.width * scale.x,
            .height = scissor.height * scale.y
        };        

        if (parent_scissor_rect != null) {
            scissor_rect = rl.getCollisionRec(scissor_rect.?, parent_scissor_rect.?);

            rl.endScissorMode();
        }

        rl.beginScissorMode(
            @as(i32, @intFromFloat(scissor_rect.?.x)),
            @as(i32, @intFromFloat(scissor_rect.?.y)),
            @as(i32, @intFromFloat(scissor_rect.?.width)),
            @as(i32, @intFromFloat(scissor_rect.?.height)),
        );

        shold_end_scissor = true;
    }
    if (reg.tryGetConst(cmp.Children, entity)) |children| {
        for (children.children.items) |child_entity| {
            try renderObjects(reg, child_entity, scissor_rect);
        }
    }

    if (shold_end_scissor) {
        rl.endScissorMode();

        if (parent_scissor_rect != null) {
            rl.beginScissorMode(
                @as(i32, @intFromFloat(parent_scissor_rect.?.x)),
                @as(i32, @intFromFloat(parent_scissor_rect.?.y)),
                @as(i32, @intFromFloat(parent_scissor_rect.?.width)),
                @as(i32, @intFromFloat(parent_scissor_rect.?.height)),
            );
        }
    }
}

pub fn render(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var roots = std.ArrayList(ecs.Entity).init(allocator);
    defer roots.deinit();

    var view = reg.view(.{ cmp.GlobalPosition, cmp.GlobalRotation, cmp.GlobalScale }, .{ cmp.Parent });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        try roots.append(entity);
    }

    if (roots.items.len > 0) {
        std.sort.heap(ecs.Entity, roots.items, reg, gameObjectRenderOrderLessThan);
        for (roots.items) |entity| {
            try renderObjects(reg, entity, null);
        }
    }
}