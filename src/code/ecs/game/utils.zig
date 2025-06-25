const std = @import("std");
const ecs = @import("zig-ecs");
const rl = @import("raylib");
const sc = @import("../../engine/scene.zig");
const pr = @import("../../engine/properties.zig");
const gameover = @import("gameover/gameover.zig");

const cmp = @import("components.zig");
const scmp = @import("../scene/components.zig");
const rcmp = @import("../render/components.zig");
const gcmp = @import("../game/components.zig");
const ccmp = @import("../core/components.zig");

pub const ALL_SCENES_PROPERTY_CHANGE_NAME = "*";

pub const ScenePropChangeItemCfg = struct {
    enter: std.json.ArrayHashMap(f64),
    exit: std.json.ArrayHashMap(f64),
};

pub const ScenePropChangeCfg = std.json.ArrayHashMap(ScenePropChangeItemCfg);
pub const LoadSceneAdditionalArgs = struct {
    props: ?*pr.Properties = null,
    change: ?*ScenePropChangeCfg = null,
};

pub const RenderLayers = struct {
    pub const GAMEPLAY = 1;
    pub const GAMEPLLAY_EFFECT = 2;
    pub const HUD = 3;
};

pub const Error = error {
    UnknownScene,
};

var scenes = &.{
    .{
        .name = "mainmenu",
        .text = @embedFile("../../assets/scenes/mainmenu.json"),
    },
    .{
        .name = "hud",
        .text = @embedFile("../../assets/scenes/hud.json"),
    },
    .{
        .name = "gameplaystart",
        .text = @embedFile("../../assets/scenes/gameplaystart.json"),
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
    .{
        .name = "gameover",
        .text = @embedFile("../../assets/scenes/gameover.json"),
    },
    .{
        .name = "gamestats",
        .text = @embedFile("../../assets/scenes/gamestats.json"),
    },
    .{
        .name = "game_menu",
        .text = @embedFile("../../assets/scenes/gamemenu.json"),
    },
    .{
        .name = "iteminfo",
        .text = @embedFile("../../assets/scenes/iteminfo.json"),
    },
    .{
        .name = "itemcollection",
        .text = @embedFile("../../assets/scenes/itemcollection.json"),
    },
    .{
        .name = "shop",
        .text = @embedFile("../../assets/scenes/shop.json"),
    },
    .{
        .name = "shopitemtemplate",
        .text = @embedFile("../../assets/scenes/shopitemtemplate.json"),
    },
    .{
        .name = "shopstalltemplate",
        .text = @embedFile("../../assets/scenes/shopstalltemplate.json"),
    },
    .{
        .name = "itemtemplate",
        .text = @embedFile("../../assets/scenes/itemtemplate.json"),
    },
};

pub fn destroyAll(comptime Component: type, reg: *ecs.Registry) void {
    var iter = reg.entityIterator(Component);
    while (iter.next()) |entity| {
        reg.addOrReplace(entity, ccmp.Destroyed {});
    }
}

pub fn gameOver(reg: *ecs.Registry, allocator: std.mem.Allocator) !void {
    var state_view = reg.view(.{ gcmp.GameState, gcmp.GameStateGameplay }, .{});
    var state_iter = state_view.entityIterator();
    while (state_iter.next()) |entity| {
        const gameplay = reg.get(gcmp.GameStateGameplay, entity);

        reg.addOrReplace(gameplay.hud_scene, ccmp.Destroyed {});
        
        destroyAll(gcmp.GameplayScene, reg);

        const gameover_scene = try gameover.loadScene(reg, allocator);
        reg.add(gameover_scene, cmp.GameoverScene {});

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

fn applyEnterChangeProps(cfg: ScenePropChangeItemCfg, props: *pr.Properties) !void {
    var change_iter = cfg.enter.map.iterator();
    while (change_iter.next()) |change_kv| {
        try props.add(change_kv.key_ptr.*, change_kv.value_ptr.*);
    }
}

pub fn loadScene(
    reg: *ecs.Registry,
    allocator: std.mem.Allocator,
    name: []const u8,
    additional: LoadSceneAdditionalArgs
) !ecs.Entity {
    inline for (scenes) |scene_desc| {
        if (std.mem.eql(u8, name, scene_desc.name)) {
            const parsed_scene = try std.json.parseFromSlice(sc.Scene, allocator, scene_desc.text, .{ .ignore_unknown_fields = true });
            
            const new_scene_entity = reg.create();
            reg.add(new_scene_entity, scmp.SceneResource { .scene = parsed_scene.value, .name = name });
            reg.add(new_scene_entity, rcmp.AttachTo { .target = null });
            reg.add(new_scene_entity, cmp.GameplayScene { .name = name });

            if (additional.change) |change| {
                if (additional.props) |props| {
                    if (change.map.get(ALL_SCENES_PROPERTY_CHANGE_NAME)) |change_item| {
                        try applyEnterChangeProps(change_item, props);
                    }

                    if (change.map.get(name)) |change_item| {
                        try applyEnterChangeProps(change_item, props);
                    }
                }
            }

            return new_scene_entity;
        }
    }

    var err = std.io.getStdErr().writer();
    try err.print("ERROR: Cannot find scene \"{s}\".\n", .{ name });

    return Error.UnknownScene;
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