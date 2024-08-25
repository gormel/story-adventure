const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const sc = @import("engine/scene.zig");
const render_systems = @import("ecs/render/systems.zig");
const rcmp = @import("ecs/render/components.zig");
const core_systems = @import("ecs/core/systems.zig");
const ccmp = @import("ecs/core/components.zig");
const input_systems = @import("ecs/input/systems.zig");
const icmp = @import("ecs/input/components.zig");
const scene_systems = @import("ecs/scene/systems.zig");
const scmp = @import("ecs/scene/components.zig");
const rs = @import("engine/resources.zig");
const game_systems = @import("ecs/game/systems.zig");
const Properties = @import("engine/parameters.zig").Properties;

const props_text = @embedFile("assets/cfg/player_properties.json");
const rules_text = @embedFile("assets/cfg/scene_rules.json");

pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1024;
    const screenHeight = 650;

    rl.InitWindow(screenWidth, screenHeight, "Journey");
    defer rl.CloseWindow(); // Close window and OpenGL context

    rl.SetTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const allocator = std.heap.page_allocator;
    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var res = rs.Resources.init(arena);

    var reg = ecs.Registry.init(arena);
    defer reg.deinit();

    var props = Properties.init(arena, &reg);

    var scanner = std.json.Scanner.initCompleteInput(arena, props_text);
    var props_json = try std.json.Value.jsonParse(arena, &scanner, .{});

    var pcg = std.rand.Pcg.init(@as(u64, @intCast(std.time.timestamp())));
    var rnd = pcg.random();

    var rules_json = try std.json.parseFromSlice(sc.Rules, arena, rules_text, .{ .ignore_unknown_fields = true });
    var rules = rules_json.value;

    //debug init

    //debug init end
    
    //game init systems
    try game_systems.initProperties(&reg, props_json.object, &props);
    try game_systems.initScene(&reg, arena);
    //game init systems end

    var timer = try std.time.Timer.start();
    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        
        const dt = @as(f32, @floatFromInt(timer.read())) / @as(f32, @floatFromInt(std.time.ns_per_s));
        timer.reset();

        //debug logic
        
        //debug logic end

        input_systems.capture(&reg, dt);

        core_systems.timer(&reg, dt);
        core_systems.destroyByTimer(&reg);

        try scene_systems.loadScene(&reg);
        try render_systems.loadResource(&reg, &res);
        try render_systems.attachTo(&reg, arena);
        try render_systems.updateGlobalTransform(&reg);
        //init obj systems
        game_systems.initButton(&reg);

        game_systems.initMainMenu(&reg);
        try game_systems.initLevel(&reg, &props, arena);
        //init obj systems end
        scene_systems.completeLoadScene(&reg);

        game_systems.button(&reg);
        game_systems.properties(&reg);
        try game_systems.changeScene(&reg, &props, &rules, &rnd, arena);

        try game_systems.mainMenu(&reg, &props);
        try game_systems.level(&reg, &props, arena);

        render_systems.setSolidRectColor(&reg);
        render_systems.setTextParams(&reg, arena);
        render_systems.blink(&reg, dt);

        rl.BeginDrawing();
        rl.ClearBackground(rl.WHITE);

        try render_systems.render(&reg);

        rl.EndDrawing();

        //destroy triggers
        try render_systems.destroyChildren(&reg);
        core_systems.destroy(&reg);
    }
}