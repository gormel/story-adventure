const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const cmp = @import("components.zig");
const rs = @import("../../engine/resources.zig");

const rcmp = @import("../render/components.zig");

pub const scene_components = .{
    rcmp.Position,
    rcmp.Rotation,
    rcmp.Scale,
    rcmp.SpriteResource,
};

const children_field = "__children__";

fn load_game_object(
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
            try load_game_object(allocator, reg, entity, jobj.object);
        }
    }
}

pub fn load_scene(allocator: std.mem.Allocator, reg: *ecs.Registry, res: *rs.Resources) !void {
    var view = reg.view(.{ cmp.SceneResource }, .{ cmp.Scene });
    var it = view.entityIterator();
    while (it.next()) |entity| {
        reg.add(entity, cmp.Scene {});

        const resource = view.getConst(cmp.SceneResource, entity);
        var scene_json = try res.load_json(resource.scene_path);

        for (scene_json.array.items) |jobj| {
            try load_game_object(allocator, reg, entity, jobj.object);
        }

        reg.remove(cmp.SceneResource, entity);
    }
}