const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const cmp = @import("components.zig");
const scmp = @import("../scene/components.zig");
const rcmp = @import("../render/components.zig");
const gcmp = @import("../game/components.zig");
const ccmp = @import("../core/components.zig");
const sc = @import("../../engine/scene.zig");
const pr = @import("../../engine/properties.zig");

const initial_scene = "main_menu";

pub const ScenePropChangeItemCfg = struct {
    enter: std.json.ArrayHashMap(f64),
    exit: std.json.ArrayHashMap(f64),
};

pub const ScenePropChangeCfg = std.json.ArrayHashMap(ScenePropChangeItemCfg);

var scenes = &.{
    .{
        .name = "main_menu",
        .text = @embedFile("../../assets/scenes/main_menu.json"),
    },
    .{
        .name = "hud",
        .text = @embedFile("../../assets/scenes/hud.json"),
    },
    .{
        .name = "gameplay_start",
        .text = @embedFile("../../assets/scenes/gameplay_start.json"),
    },
    .{
        .name = "empty",
        .text = @embedFile("../../assets/scenes/empty.json"),
    },
    .{
        .name = "loot",
        .text = @embedFile("../../assets/scenes/loot.json"),
    },
    .{
        .name = "combat",
        .text = @embedFile("../../assets/scenes/combat.json"),
    },
};

pub fn gameOver(reg: *ecs.Registry, props: *pr.Properties, change: *ScenePropChangeCfg, allocator: std.mem.Allocator) !void {
    var state_view = reg.view(.{ gcmp.GameState, gcmp.GameStateGameplay }, .{});
    var state_iter = state_view.entityIterator();
    while (state_iter.next()) |entity| {
        var gameplay = reg.get(gcmp.GameStateGameplay, entity);
        if (!reg.has(ccmp.Destroyed, gameplay.hud_scene)) {
            reg.add(gameplay.hud_scene, ccmp.Destroyed {});
        }

        var scene_view = reg.view(.{ gcmp.GameplayScene }, .{});
        var scene_iter = scene_view.entityIterator();
        while (scene_iter.next()) |scene_entity| {
            if (!reg.has(ccmp.Destroyed, scene_entity)) {
                reg.add(scene_entity, ccmp.Destroyed {});
            }
        }

        _ = try loadScene(reg, props, change, allocator, initial_scene);

        reg.remove(gcmp.GameStateGameplay, entity);
    }
}

pub fn selectNextScene(reg: *ecs.Registry) void {
    var scene_view = reg.view(.{ scmp.Scene, cmp.GameplayScene }, .{ cmp.NextGameplayScene });
    var scene_iter = scene_view.entityIterator();
    while (scene_iter.next()) |entity| {
        reg.add(entity, cmp.NextGameplayScene {});
    }
}

pub fn loadScene(reg: *ecs.Registry, props: *pr.Properties, change: *ScenePropChangeCfg, allocator: std.mem.Allocator, name: []const u8) !ecs.Entity {
    inline for (scenes) |scene_desc| {
        if (std.mem.eql(u8, name, scene_desc.name)) {
            const parsed_scene = try std.json.parseFromSlice(sc.Scene, allocator, scene_desc.text, .{ .ignore_unknown_fields = true });
            
            var new_scene_entity = reg.create();
            reg.add(new_scene_entity, scmp.SceneResource { .scene = parsed_scene.value });
            reg.add(new_scene_entity, rcmp.Position { .x = 0, .y = 0 });
            reg.add(new_scene_entity, rcmp.AttachTo { .target = null });
            reg.add(new_scene_entity, cmp.GameplayScene { .name = name });

            if (change.map.get(name)) |change_item| {
                var change_iter = change_item.enter.map.iterator();
                while (change_iter.next()) |change_kv| {
                    try props.add(change_kv.key_ptr.*, change_kv.value_ptr.*);
                }
            }

            return new_scene_entity;
        }
    }

    unreachable;
}

pub fn queryScene(reg: *ecs.Registry, obj_entity: ecs.Entity) ?ecs.Entity {
    var caret: ?ecs.Entity = obj_entity;
    while (caret != null and !reg.has(scmp.Scene, caret.?)) {
        if (reg.tryGet(rcmp.Parent, caret.?)) |parent| {
            caret = parent.entity;
        } else if (reg.tryGet(rcmp.AttachTo, caret.?)) |attach| {
            caret = attach.target;
        } else {
            caret = null;
        }
    }
    return caret;
}