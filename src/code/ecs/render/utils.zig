const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const utils = @import("../../engine/utils.zig");

const cmp = @import("components.zig");

pub fn getParent(reg: *ecs.Registry, entity: ecs.Entity) ?ecs.Entity {
    if (reg.tryGet(cmp.Parent, entity)) |parent| {
        return parent.entity;
    } else if (reg.tryGet(cmp.AttachTo, entity)) |attach| {
        return attach.target;
    }

    return null;
}

pub fn worldToLocalXY(reg: *ecs.Registry, entity: ecs.Entity, x: *f32, y: *f32) void {
    if (reg.tryGetConst(cmp.GlobalPosition, entity)) |g_position| {
        x.* -= g_position.x;
        y.* -= g_position.y;
    }

    if (reg.tryGetConst(cmp.GlobalScale, entity)) |g_scale| {
        x.* /= g_scale.x;
        y.* /= g_scale.y;
    }

    if (reg.tryGetConst(cmp.GlobalRotation, entity)) |g_rotation| {
        utils.rotate(x, y, -g_rotation.a);
    }
}

pub fn localToWorldXY(reg: *ecs.Registry, entity: ecs.Entity, x: *f32, y: *f32) void {
    if (reg.tryGetConst(cmp.GlobalRotation, entity)) |g_rotation| {
        utils.rotate(x, y, g_rotation.a);
    }

    if (reg.tryGetConst(cmp.GlobalScale, entity)) |g_scale| {
        x.* *= g_scale.x;
        y.* *= g_scale.y;
    }
    
    if (reg.tryGetConst(cmp.GlobalPosition, entity)) |g_position| {
        x.* += g_position.x;
        y.* += g_position.y;
    }
}