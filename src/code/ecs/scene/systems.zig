const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const rs = @import("../../engine/resources.zig");

const rcmp = @import("../render/components.zig");
const gcmp = @import("../gui/components.zig");
const ecmp = @import("../editor/components.zig");

pub const scene_components = .{
    rcmp.Position,
    rcmp.Rotation,
    rcmp.Scale,
    rcmp.SolidRect,
    rcmp.Text,
    rcmp.Disabled,
    rcmp.Hidden,
    rcmp.Scissor,

    gcmp.LinearLayout,
    gcmp.Collapsed,

    cmp.Sprite,
    cmp.Button,
    cmp.LayoutElement,
    cmp.Scroll,
    cmp.ObjectName,
    cmp.TextInput,

    ecmp.GameObjectPanel,
    ecmp.ComponentPanel,
    ecmp.NewEntityButton,
    ecmp.ComponentInstancePanel,
    ecmp.EditComponentWindow,
};

const children_field = "__children__";

fn loadGameObject(
    allocator: std.mem.Allocator,
    reg: *ecs.Registry,
    parent_ety: ecs.Entity,
    json: std.json.ObjectMap
) std.json.ParseFromValueError!void {
    var entity = reg.create();
    reg.add(entity, cmp.GameObject {});
    reg.add(entity, rcmp.AttachTo { .target = parent_ety });

    inline for (scene_components) |cmp_type| {
        if (json.get(@typeName(cmp_type))) |jobj| {
            var parsed = try std.json.parseFromValue(cmp_type, allocator, jobj, .{});
            reg.addTyped(cmp_type, entity, parsed.value);
        }
    }

    if (json.get(children_field)) |jchildren| {
        for (jchildren.array.items) |jobj| {
            try loadGameObject(allocator, reg, entity, jobj.object);
        }
    }
}

pub fn loadScene(reg: *ecs.Registry, allocator: std.mem.Allocator, res: *rs.Resources) !void {
    var view = reg.view(.{ cmp.SceneResource }, .{ cmp.Scene });
    var it = view.entityIterator();
    while (it.next()) |entity| {
        reg.add(entity, cmp.Scene {});

        const resource = view.getConst(cmp.SceneResource, entity);
        var scene_json = try res.loadJson(resource.scene_path);

        for (scene_json.array.items) |jobj| {
            try loadGameObject(allocator, reg, entity, jobj.object);
        }

        reg.remove(cmp.SceneResource, entity);
    }
}

pub fn applyInits(reg: *ecs.Registry) void {
    var sprite_view = reg.view(.{ cmp.Sprite }, .{ cmp.SpriteLoaded });
    var sprite_iter = sprite_view.entityIterator();
    while (sprite_iter.next()) |entity| {
        const sprite = sprite_view.getConst(cmp.Sprite, entity);
        reg.add(entity, rcmp.SpriteResource {
            .atlas_path = sprite.atlas_path,
            .sprite = sprite.sprite,
        });

        reg.add(entity, cmp.SpriteLoaded {});
    }

    var text_input_view = reg.view(.{ cmp.TextInput }, .{ cmp.TextInputLoaded });
    var text_input_iter = text_input_view.entityIterator();
    while (text_input_iter.next()) |entity| {
        const text_input = text_input_view.getConst(cmp.TextInput, entity);
        reg.add(entity, gcmp.InitTextInput {
            .bg_color = text_input.bg_color,
            .text_color = text_input.text_color,
            .rect = text_input.rect,
        });

        reg.add(entity, cmp.TextInputLoaded {});
    }

    var button_view = reg.view(.{ cmp.Button }, .{ cmp.ButtonLoaded });
    var button_iter = button_view.entityIterator();
    while (button_iter.next()) |entity| {
        const button = button_view.getConst(cmp.Button, entity);
        reg.add(entity, gcmp.InitButton {
            .color = button.color,
            .rect = button.rect,
        });

        reg.add(entity, cmp.ButtonLoaded {});
    }

    var scroll_view = reg.view(.{ cmp.Scroll }, .{ cmp.ScrollLoaded });
    var scroll_iter = scroll_view.entityIterator();
    while (scroll_iter.next()) |entity| {
        const scroll = scroll_view.getConst(cmp.Scroll, entity);
        reg.add(entity, gcmp.InitScroll {
            .view_area = scroll.view_area,
            .dir = scroll.dir,
            .speed = scroll.speed,
        });

        reg.add(entity, cmp.ScrollLoaded {});
    }
    
    var element_view = reg.view(.{ cmp.LayoutElement }, .{ cmp.LayoutElementLoaded });
    var element_iter = element_view.entityIterator();
    while (element_iter.next()) |entity| {
        const element = element_view.getConst(cmp.LayoutElement, entity);
        reg.add(entity, gcmp.InitLayoutElement {
            .width = element.width,
            .height = element.height,
            .idx = element.idx,
        });

        reg.add(entity, cmp.LayoutElementLoaded {});
    }
}