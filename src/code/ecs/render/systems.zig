const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");

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

pub fn rotate(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.Rotation }, .{ });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var rot = view.get(entity);
        rot.a += 0.3;
    }
}

pub fn render(reg: *ecs.Registry) void {
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

        const target_rect = rl.Rectangle { .x = pos.x, .y = pos.y, .width = sprite.rect.width, .height = sprite.rect.height };
        rl.DrawTexturePro(sprite.tex, sprite.rect, target_rect, origin, angle, rl.WHITE);
    }
}