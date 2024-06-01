const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const rcmp = @import("../render/components.zig");
const rs = @import("../../engine/resources.zig");
const sc = @import("../../engine/scene.zig");
const gui_setup = @import("../../engine/gui_setup.zig");

fn createGameObjects(reg: *ecs.Registry, parent_ety: ecs.Entity, obj_descriptions: []sc.SceneObject) void {
    for (obj_descriptions) |obj_description| {
        var obj_ety = reg.create();

        reg.add(obj_ety, rcmp.AttachTo { .target = parent_ety });
        reg.add(obj_ety, rcmp.Position { .x = obj_description.position.x, .y = obj_description.position.y });
        reg.add(obj_ety, cmp.GameObject { .tags = obj_description.tags });

        if (obj_description.sprite) |obj_sprite| {
            reg.add(obj_ety, rcmp.SpriteResource {
                .atlas =  obj_sprite.atlas,
                .sprite = obj_sprite.sprite,
            });
        }

        if (obj_description.text) |obj_text| {
            reg.add(obj_ety, rcmp.Text {
                .text = obj_text.text,
                .size = obj_text.size,
                .color = gui_setup.ColorLabelText,
            });
        }

        createGameObjects(reg, obj_ety, obj_description.children);
    }
}

pub fn loadScene(reg: *ecs.Registry) !void {
    var view = reg.view(.{ cmp.SceneResource }, .{ cmp.Scene });
    var it = view.entityIterator();
    while (it.next()) |entity| {
        reg.add(entity, cmp.Scene {});
        const resource = view.getConst(cmp.SceneResource, entity);

        createGameObjects(reg, entity, resource.scene);

        reg.remove(cmp.SceneResource, entity);
    }
}