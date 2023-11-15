const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const Destroyed = @import("../core/components.zig").Destroyed;

pub fn load_resource(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.Resource }, .{ cmp.Sprite });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const res = view.getConst(cmp.Resource, entity);
        const tex = rl.LoadTexture(res.path.ptr);
        const rect = rl.Rectangle { .x = 0, .y = 0, .width = @floatFromInt(tex.width), .height = @floatFromInt(tex.height) };
        reg.add(entity, cmp.Sprite{ .tex = tex, .rect = rect });
        reg.remove(cmp.Resource, entity);
    }
}

pub fn free_sprite(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.Sprite, Destroyed }, .{ });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var sprite = view.get(cmp.Sprite, entity);
        rl.UnloadTexture(sprite.tex);
    }
}

pub fn render_sprite(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.Sprite, cmp.Position }, .{ });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const sprite = view.getConst(cmp.Sprite, entity);
        const pos = view.getConst(cmp.Position, entity);

        var angle: f32 = 0;
        if (reg.has(cmp.Rotation, entity)) {
            const rot = reg.getConst(cmp.Rotation, entity);
            angle = rot.a;
        }

        var origin = rl.Vector2 { .x = 0, .y = 0 };
        if (reg.has(cmp.SpriteOffset, entity)) {
            const offset = reg.getConst(cmp.SpriteOffset, entity);
            origin.x = offset.x;
            origin.y = offset.y;
        }

        var scale_x: f32 = 1;
        var scale_y: f32 = 1;
        if (reg.has(cmp.Scale, entity)) {
            const scale = reg.getConst(cmp.Scale, entity);
            scale_x = scale.x;
            scale_y = scale.y;
        }
        const target_rect = rl.Rectangle {
            .x = pos.x, .y = pos.y,
            .width = sprite.rect.width * scale_x,
            .height = sprite.rect.height * scale_y
        };
        rl.DrawTexturePro(sprite.tex, sprite.rect, target_rect, origin, angle, rl.WHITE);
    }
}