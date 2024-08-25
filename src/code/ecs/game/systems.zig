const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const cmp = @import("components.zig");
const utils = @import("../../engine/utils.zig");
const scmp = @import("../scene/components.zig");
const icmp = @import("../input/components.zig");
const rcmp = @import("../render/components.zig");
const ccmp = @import("../core/components.zig");
const Scene = @import("../../engine/scene.zig").Scene;
const Properties = @import("../../engine/parameters.zig").Properties;

const SceneDesc = struct { name: []const u8, text: []const u8 };

var scenes = &.{
    .{
        .name = "main_menu",
        .text = @embedFile("../../assets/scenes/test_scene.json"),
    },
    .{
        .name = "level_01",
        .text = @embedFile("../../assets/scenes/test_scene.json"),
    },
    .{
        .name = "game_over",
        .text = @embedFile("../../assets/scenes/test_scene.json"),
    },
};

pub fn initButton(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject, rcmp.Sprite }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "button")) {
            reg.add(entity, cmp.Button {});
            const sprite = view.getConst(rcmp.Sprite, entity);
            
            reg.add(entity, icmp.MouseOverTracker { .rect = sprite.sprite.rect });
            reg.add(entity, icmp.MouseButtonTracker { .button = rl.MOUSE_BUTTON_LEFT });
        }
    }
}

pub fn button(reg: *ecs.Registry) void {
    var clicked_iter = reg.entityIterator(cmp.ButtonClicked);
    while (clicked_iter.next()) |entity| {
        reg.remove(cmp.ButtonClicked, entity);
    }

    var view = reg.view(.{ icmp.MouseOver, icmp.InputPressed, cmp.Button }, .{ cmp.ButtonClicked });
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        reg.add(entity, cmp.ButtonClicked {});
    }
}

pub fn initProperties(reg: *ecs.Registry, json: std.json.ObjectMap, props: *Properties) !void {
    _ = reg;
    for (json.keys()) |key| {
        if (json.get(key)) |value| {
            try props.set(key, value.float);
        }
    }
}

pub fn properties(reg: *ecs.Registry) void {
    var cleanup_view = reg.view(.{ cmp.PlayerPropertyChanged }, .{});
    var cleanup_iter = cleanup_view.entityIterator();
    while (cleanup_iter.next()) |entity| {
        reg.remove(cmp.PlayerPropertyChanged, entity);
        reg.add(entity, ccmp.Destroyed {});
    }

    var set_view = reg.view(.{ cmp.TriggerPlayerPropertyChanged }, .{});
    var set_iter = set_view.entityIterator();
    while (set_iter.next()) |entity| {
        var trigger = reg.get(cmp.TriggerPlayerPropertyChanged, entity);
        reg.add(entity, cmp.PlayerPropertyChanged { .name = trigger.name });
        reg.remove(cmp.TriggerPlayerPropertyChanged, entity);
    }
}