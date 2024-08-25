const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const cmp = @import("components.zig");
const utils = @import("../../engine/utils.zig");
const scmp = @import("../scene/components.zig");
const icmp = @import("../input/components.zig");
const rcmp = @import("../render/components.zig");
const ccmp = @import("../core/components.zig");
const sc = @import("../../engine/scene.zig");
const Properties = @import("../../engine/parameters.zig").Properties;

const SceneDesc = struct { name: []const u8, text: []const u8 };

var scenes = &.{
    .{
        .name = "main_menu",
        .text = @embedFile("../../assets/scenes/main_menu.json"),
    },
    .{
        .name = "level_01",
        .text = @embedFile("../../assets/scenes/level_01.json"),
    },
    .{
        .name = "game_over",
        .text = @embedFile("../../assets/scenes/main_menu.json"),
    },
};

const initial_scene = "main_menu";

pub fn initButton(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject, rcmp.Sprite }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "button")) {
            reg.add(entity, cmp.Button {});
            const sprite = view.getConst(rcmp.Sprite, entity);
            
            reg.add(entity, icmp.MousePositionTracker { });
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

fn checkNames(a: ?[]const u8, b: ?[]const u8) bool {
    if (a != null) {
        if (b != null) {
            return std.mem.eql(u8, a.?, b.?);
        } else {
            return false;
        }
    } else {
        if (b != null) {
            return false;
        } else {
            return true;
        }
    }
}

fn checkCondition(params: []sc.RuleParam, props: *Properties) bool {
    if (params.len == 0) {
        return true;
    }

    for (params) |param| {
        var value = try props.get(param.name);
        switch (param.operator) {
            .LT => { if (value >= param.value) { return false; } },
            .LE => { if (value > param.value) { return false; } },
            .EQ => { if (value != param.value) { return false; } },
            .GE => { if (value < param.value) { return false; } },
            .GT => { if (value <= param.value) { return false; } },
        }
    }
    return true;
}

fn loadScene(reg: *ecs.Registry, allocator: std.mem.Allocator, name: []const u8) !void {
    inline for (scenes) |scene_desc| {
        if (std.mem.eql(u8, name, scene_desc.name)) {
            const parsed_scene = try std.json.parseFromSlice(sc.Scene, allocator, scene_desc.text, .{ .ignore_unknown_fields = true });
            
            var new_scene_entity = reg.create();
            reg.add(new_scene_entity, scmp.SceneResource { .scene = parsed_scene.value });
            reg.add(new_scene_entity, rcmp.Position { .x = 0, .y = 0 });
            reg.add(new_scene_entity, rcmp.AttachTo { .target = null });
            reg.add(new_scene_entity, cmp.GameplayScene { .name = name });
        }
    }
}

pub fn initScene(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    try loadScene(reg, allocator, initial_scene);
}

pub fn changeScene(reg: *ecs.Registry, props: *Properties, rules: *sc.Rules, rnd: *std.rand.Random, allocator: std.mem.Allocator) !void {
    var view = reg.view(.{ cmp.GameplayScene, cmp.NextGameplayScene }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var scene = reg.get(cmp.GameplayScene, entity);
        var scene_name = scene.name;

        var max_roll: f64 = 0;
        var rule_count: usize = 0;
        var rules_to_roll = try allocator.alloc(sc.Rule, rules.*.len);
        defer allocator.free(rules_to_roll);
        for (rules.*) |rule| {
            if (
                checkNames(rule.current_scene, scene_name)
                and checkCondition(rule.params, props)
            ) {
                rules_to_roll[rule_count] = rule;
                rule_count += 1;
                max_roll += rule.weight;
            }
        }

        if (max_roll > 0) {
            var roll = rnd.float(f64) * max_roll;
            var prev_weight: f64 = 0;
            for (0..rule_count) |i| {
                var rule = rules_to_roll[i];
                if (roll >= prev_weight and roll < prev_weight + rule.weight) {
                    reg.add(entity, ccmp.Destroyed {});

                    try loadScene(reg, allocator, rule.result_scene);
                    break;
                }
                prev_weight += rule.weight;
            }
        }
        
        reg.remove(cmp.NextGameplayScene, entity);
    }
}

fn selectNextScene(reg: *ecs.Registry) void {
    var scene_view = reg.view(.{ scmp.Scene, cmp.GameplayScene }, .{ cmp.NextGameplayScene });
    var scene_iter = scene_view.entityIterator();
    while (scene_iter.next()) |entity| {
        reg.add(entity, cmp.NextGameplayScene {});
    }
}

pub fn initMainMenu(reg: *ecs.Registry) void {
    var view = reg.view(.{ scmp.InitGameObject }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "button-start-game")) {
            reg.add(entity, cmp.StartGameButton {});
        }
    }
}

pub fn mainMenu(reg: *ecs.Registry, props: *Properties) !void {
    var view = reg.view(.{ cmp.StartGameButton, cmp.ButtonClicked }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |_| {
        try props.set("health", 100);

        selectNextScene(reg);
    }
}

pub fn initLevel(reg: *ecs.Registry, props: *Properties, allocator: std.mem.Allocator) !void {
    var iter = reg.entityIterator(scmp.InitGameObject);
    while (iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "button-next-level")) {
            reg.add(entity, cmp.NextLevelButton {});
        }
    }

    var ph_iter = reg.entityIterator(scmp.InitGameObject);
    while (ph_iter.next()) |entity| {
        const init = reg.get(scmp.InitGameObject, entity);
        if (utils.containsTag(init.tags, "view-hp")) {
            reg.add(entity, cmp.ViewCurrentHp {});
            
            var hp = try props.get("health");
            reg.add(entity, rcmp.SetTextValue {
                .text = try std.fmt.allocPrintZ(allocator, "{d}", .{ hp }),
            });
        }
    }
}

pub fn level(reg: *ecs.Registry, props: *Properties, allocator: std.mem.Allocator) !void {
    var view = reg.view(.{ cmp.NextLevelButton, cmp.ButtonClicked }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |_| {
        try props.set("health", (try props.get("health")) - 10);

        selectNextScene(reg);
    }

    var hp_prop_iter = reg.entityIterator(cmp.PlayerPropertyChanged);
    while (hp_prop_iter.next()) |entity| {
        const changed = reg.get(cmp.PlayerPropertyChanged, entity);
        if (std.mem.eql(u8, changed.name, "health")) {
            var view_view = reg.view(.{ rcmp.Text, cmp.ViewCurrentHp }, .{ rcmp.SetTextValue });
            var hp = try props.get("health");
            var view_iter = view_view.entityIterator();
            while (view_iter.next()) |view_entity| {
                reg.add(view_entity, rcmp.SetTextValue {
                    .text = try std.fmt.allocPrintZ(allocator, "{d}", .{ hp }),
                    .free = true,
                });
            }
        }
    }
}