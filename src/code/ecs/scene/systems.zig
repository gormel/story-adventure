const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const rcmp = @import("../render/components.zig");
const rs = @import("../../engine/resources.zig");
const sc = @import("../../engine/scene.zig");
const gui_setup = @import("../../engine/gui_setup.zig");

fn createGameObjects(reg: *ecs.Registry, parent_ety: ecs.Entity, obj_descriptions: []sc.SceneObject, scene: ecs.Entity) void {
    for (obj_descriptions, 0..) |obj_description, idx| {
        const obj_ety = reg.create();

        reg.add(obj_ety, rcmp.AttachTo { .target = parent_ety });
        reg.add(obj_ety, rcmp.Position { .x = obj_description.position.x, .y = obj_description.position.y });
        reg.add(obj_ety, cmp.InitGameObject { .tags = obj_description.tags, .scene = scene });
        reg.add(obj_ety, rcmp.Order { .order = @intCast(idx) });

        if (obj_description.image) |obj_image| {
            reg.add(obj_ety, rcmp.ImageResource {
                .atlas =  obj_image.atlas,
                .image = obj_image.image,
            });
        }

        if (obj_description.text) |obj_text| {
            reg.add(obj_ety, rcmp.Text {
                .text = obj_text.text,
                .size = obj_text.size,
                .color = gui_setup.ColorLabelText,
                .free = false,
            });
        }

        createGameObjects(reg, obj_ety, obj_description.children, scene);
    }
}

pub fn loadScene(reg: *ecs.Registry) !void {
    var view = reg.view(.{ cmp.SceneResource }, .{ cmp.Scene });
    var it = view.entityIterator();
    while (it.next()) |entity| {
        const resource = view.getConst(cmp.SceneResource, entity);
        reg.add(entity, cmp.Scene { .name = resource.name });

        createGameObjects(reg, entity, resource.scene, entity);

        reg.remove(cmp.SceneResource, entity);
    }
}

pub fn completeLoadScene(reg: *ecs.Registry) void {
    var view = reg.view(.{ cmp.InitGameObject }, .{ cmp.GameObject });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.remove(cmp.InitGameObject, entity);
        reg.add(entity, cmp.GameObject {});
    }
}