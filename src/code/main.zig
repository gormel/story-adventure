const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const assets = @import("assets");
const sc = @import("engine/scene.zig");
const render_systems = @import("ecs/render/systems.zig");
const core_systems = @import("ecs/core/systems.zig");
const input_systems = @import("ecs/input/systems.zig");
const scene_systems = @import("ecs/scene/systems.zig");
const rs = @import("engine/resources.zig");
const game_systems = @import("ecs/game/systems.zig");
const pr = @import("engine/properties.zig");
const itm = @import("engine/items.zig");
const game = @import("ecs/game/utils.zig");
const is = @import("ecs/input/inputstack.zig");

const rcmp = @import("ecs/render/components.zig");
const ccmp = @import("ecs/core/components.zig");
const icmp = @import("ecs/input/components.zig");
const scmp = @import("ecs/scene/components.zig");

const props_text = @embedFile("assets/cfg/player_properties.json");
const rules_text = @embedFile("assets/cfg/scene_rules.json");
const propsetup_text = @embedFile("assets/cfg/property_setup.json");

pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1024;
    const screenHeight = 650;

    rl.initWindow(screenWidth, screenHeight, "Journey");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const allocator = std.heap.page_allocator;
    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var res = try rs.Resources.init(arena);

    var reg = ecs.Registry.init(arena);
    defer reg.deinit();

    var input_stack = is.InputStack.init(arena);
    defer input_stack.deinit();

    var propsetup_json = try std.json.parseFromSlice(pr.Setup, arena, propsetup_text, .{ .ignore_unknown_fields = true });
    var props = pr.Properties.init(arena, &reg, &propsetup_json.value);
    defer props.deinit();

    var scanner = std.json.Scanner.initCompleteInput(arena, props_text);
    const props_json = try std.json.Value.jsonParse(arena, &scanner, .{ .max_value_len = 4096 });

    const items_cfg_text = @embedFile("assets/cfg/items.json");
    var items_cfg_json = try std.json.parseFromSlice(itm.ItemListCfg, arena, items_cfg_text, .{ .ignore_unknown_fields = true });
    defer items_cfg_json.deinit();

    const item_drop_cfg_text = @embedFile("assets/cfg/item_drop.json");
    var item_drop_cfg_json = try std.json.parseFromSlice(itm.ItemDropListCfg,
        arena, item_drop_cfg_text, .{ .ignore_unknown_fields = true });
    defer item_drop_cfg_json.deinit();

    const item_progress_cfg_text = @embedFile("assets/cfg/item_progress.json");
    var item_progress_cfg_json = try std.json.parseFromSlice(itm.ItemProgressCfg,
        arena, item_progress_cfg_text, .{ .ignore_unknown_fields = true });
    defer item_progress_cfg_json.deinit();

    var items = itm.Items.init(
        &items_cfg_json.value,
        &item_drop_cfg_json.value,
        &item_progress_cfg_json.value,
        &props, arena);

    var pcg = std.Random.Pcg.init(@as(u64, @intCast(std.time.timestamp())));
    //var pcg = std.rand.Pcg.init(123456789);
    var rnd = pcg.random();

    var rules_json = try std.json.parseFromSlice(sc.Rules, arena, rules_text, .{ .ignore_unknown_fields = true });
    defer rules_json.deinit();
    var rules = rules_json.value;

    const scene_prop_change_text = @embedFile("assets/cfg/scene_property_change.json");
    var scene_prop_change_json = try std.json.parseFromSlice(
        game.ScenePropChangeCfg, arena, scene_prop_change_text, .{ .ignore_unknown_fields = true });
    //debug init

    //debug init end
    
    //game init systems
    try game_systems.initProperties(&reg, props_json.object, &props);
    try game_systems.initScene(&reg, arena);
    render_systems.initFont(&reg, &res);
    //game init systems end

    var timer = try std.time.Timer.start();
    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        
        const dt = @as(f32, @floatFromInt(timer.read())) / @as(f32, @floatFromInt(std.time.ns_per_s));
        timer.reset();

        //debug logic
        
        //debug logic end

        input_systems.capture(&reg, dt, input_stack);

        core_systems.timer(&reg, dt);
        core_systems.destroyByTimer(&reg);

        try scene_systems.loadScene(&reg);
        try render_systems.loadResource(&reg, &res);
        try render_systems.attachTo(&reg, arena);
        try render_systems.updateGlobalTransform(&reg);

        game_systems.layoutChildren(&reg);
        //init obj systems
        try game_systems.inputCapture(&reg, &input_stack);
        game_systems.initButton(&reg);

        try game_systems.initGameplayCustoms(&reg, &props, arena, &rnd);
        //init obj systems end
        scene_systems.completeLoadScene(&reg);

        game_systems.button(&reg, dt);
        game_systems.message(&reg, dt);
        game_systems.hover(&reg);
        game_systems.properties(&reg);
        try game_systems.changeScene(&reg, &props, &rules, &scene_prop_change_json.value, &rnd, arena);

        try game_systems.updateGameplayCustoms(&reg, &props, &scene_prop_change_json.value, arena, &items, &rnd, dt);

        render_systems.setSolidRectColor(&reg);
        render_systems.setTextParams(&reg, arena);
        render_systems.blink(&reg, dt);
        render_systems.updateFlipbook(&reg, dt);
        render_systems.tween(&reg, dt);

        rl.beginDrawing();
        rl.clearBackground(rl.Color.white);

        try render_systems.render(&reg, arena);

        rl.endDrawing();

        //destroy triggers
        try game_systems.freeGameplayCustoms(&reg);
        game_systems.freeInputCapture(&reg, &input_stack);
        render_systems.freeFlipbook(&reg);
        try render_systems.destroyChildren(&reg);
        core_systems.destroy(&reg);
    }

    //gameplay free

    //gameplay free end
}