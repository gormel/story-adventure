const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const Destroyed = @import("../core/components.zig").Destroyed;
const DestroyNextFrame = @import("../core/components.zig").DestroyNextFrame;
const rs = @import("../../engine/resources.zig");
const qu = @import("../../engine/queue.zig");
const utils = @import("../../engine/utils.zig");

const NoParentGlobalTransform = error{ NoParentGlobalTransform };

pub fn load_resource(reg: *ecs.Registry, res: *rs.Resources) !void {
    var view = reg.view(.{ cmp.SpriteResource }, .{ cmp.Sprite });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const res_c = view.getConst(cmp.SpriteResource, entity);
        reg.add(entity, cmp.Sprite {
            .sprite = try res.load_sprite(res_c.atlas_path, res_c.sprite)
        });
        reg.remove(cmp.SpriteResource, entity);
    }
}

fn do_update_global_transform(reg: *ecs.Registry, entity: ecs.Entity) (NoParentGlobalTransform || error {OutOfMemory})!void {
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
            try do_update_global_transform(reg, child);
        }
    }
}

fn topo_sort(reg: *ecs.Registry, entity: ecs.Entity, out_list: *std.ArrayList(ecs.Entity), allocator: std.mem.Allocator) !void {
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

fn index_of(comptime T: type, slice: std.ArrayList(T).Slice, value: T) ?usize {
    return
        for(slice, 0..) |now_value, index| {
            if (now_value == value) {
                break index;
            }
        } else null;
}

fn detach_parent(reg: *ecs.Registry, entity: ecs.Entity) !void {
    const parent = reg.getConst(cmp.Parent, entity);
    var parent_children = reg.get(cmp.Children, parent.entity);
    while (index_of(ecs.Entity, parent_children.children.items, entity))|at_idx| {
        _ = parent_children.children.swapRemove(at_idx);
    }
    reg.remove(cmp.Parent, entity);
}

pub fn attach_to(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var detach_view = reg.view(.{ cmp.AttachTo, cmp.Parent }, .{ });
    var detach_iter = detach_view.entityIterator();
    while (detach_iter.next()) |entity| {
        const attach = detach_view.getConst(cmp.AttachTo, entity);
        const parent = detach_view.getConst(cmp.Parent, entity);
        if (attach.target != parent.entity) {
            try detach_parent(reg, entity);
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

pub fn update_global_transform(reg: *ecs.Registry) !void {
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
        try do_update_global_transform(reg, entity);
        reg.remove(cmp.UpdateGlobalTransform, entity);
        updated = true;
    }
}

pub fn destroy_children(reg: *ecs.Registry) !void {
    var parent_view = reg.view(.{ Destroyed, cmp.Parent }, .{ });
    var parent_iter = parent_view.entityIterator();
    while (parent_iter.next()) |entity| {
        try detach_parent(reg, entity);
    }
    
    var children_view = reg.view(.{ Destroyed, cmp.Children }, .{ });
    var children_iter = children_view.entityIterator();
    while (children_iter.next()) |entity| {
        var children = children_view.get(cmp.Children, entity);
        for (children.children.items) |child_entity| {
            reg.add(child_entity, DestroyNextFrame {});
            if (reg.has(cmp.Parent, child_entity)) {
                reg.remove(cmp.Parent, child_entity);
            }
        }
    }
}

pub fn set_solid_rect_color(reg: *ecs.Registry) void {
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

pub fn set_text_params(reg: *ecs.Registry) void {
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

       text.text = set.text;
       reg.remove(cmp.SetTextValue, entity);
       reg.add(entity, cmp.TextValueUpdated {});
    }

}

fn render_sprite(reg: *ecs.Registry, entity: ecs.Entity) !void {
    const sprite = reg.getConst(cmp.Sprite, entity);
    const pos = reg.getConst(cmp.GlobalPosition, entity);
    const rot = reg.getConst(cmp.GlobalRotation, entity);
    const scale = reg.getConst(cmp.GlobalScale, entity);

    var origin = rl.Vector2 { .x = 0, .y = 0 };
    if (reg.tryGetConst(cmp.SpriteOffset, entity)) |offset| {
        origin.x = offset.x;
        origin.y = offset.y;
    }

    const target_rect = rl.Rectangle {
        .x = pos.x, .y = pos.y,
        .width = sprite.sprite.rect.width * scale.x,
        .height = sprite.sprite.rect.height * scale.y
    };
    rl.DrawTexturePro(sprite.sprite.tex, sprite.sprite.rect, target_rect, origin, rot.a, rl.WHITE);
}

fn render_solid_rect(reg: *ecs.Registry, entity: ecs.Entity) !void {
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

    rl.DrawRectanglePro(target_rect, origin, rot.a, rect.color);
}

fn render_text(reg: *ecs.Registry, entity: ecs.Entity) !void {
    const text = reg.getConst(cmp.Text, entity);
    const pos = reg.getConst(cmp.GlobalPosition, entity);
    const rot = reg.getConst(cmp.GlobalRotation, entity);
    //const scale = reg.getConst(cmp.GlobalScale, entity);

    var origin = rl.Vector2 { .x = 0, .y = 0 };
    if (reg.tryGetConst(cmp.TextOffset, entity)) |offset| {
        origin.x = offset.x;
        origin.y = offset.y;
    }

    var position = rl.Vector2 { .x = pos.x, .y = pos.y };

    rl.DrawTextPro(rl.GetFontDefault(), text.text.ptr, position, origin, rot.a, text.size, 3, text.color);
}

const render_fns = .{
    .{ .cmp = cmp.Sprite, .func = render_sprite },
    .{ .cmp = cmp.SolidRect, .func = render_solid_rect },
    .{ .cmp = cmp.Text, .func = render_text },
};

fn render_object(reg: *ecs.Registry, entity: ecs.Entity) void {
    const group = reg.group(.{ cmp.GlobalPosition, cmp.GlobalRotation, cmp.GlobalScale }, .{}, .{ cmp.Hidden });
    inline for (render_fns) |map| {
        if (
            reg.has(map.cmp, entity)
            and group.contains(entity)
        ) {
            try map.func(reg, entity);
        }
    }

    var shold_end_scissor = false;
    if (reg.tryGetConst(cmp.Scissor, entity)) |scissor| {
        const pos = reg.getConst(cmp.GlobalPosition, entity);
        const scale = reg.getConst(cmp.GlobalScale, entity);

        rl.BeginScissorMode(
            @as(i32, @intFromFloat(pos.x)),
            @as(i32, @intFromFloat(pos.y)),
            @as(i32, @intFromFloat(scissor.width * scale.x)),
            @as(i32, @intFromFloat(scissor.height * scale.y)),
        );

        shold_end_scissor = true;
    }
    if (reg.tryGetConst(cmp.Children, entity)) |children| {
        for (children.children.items) |child_entity| {
            render_object(reg, child_entity);
        }
    }

    if (shold_end_scissor) {
        rl.EndScissorMode();
    }
}

pub fn render(reg: *ecs.Registry) !void {
    var view = reg.view(.{ cmp.GlobalPosition, cmp.GlobalRotation, cmp.GlobalScale }, .{ cmp.Parent });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        render_object(reg, entity);
    }
}