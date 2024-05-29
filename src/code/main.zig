const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const render_systems = @import("ecs/render/systems.zig");
const rcmp = @import("ecs/render/components.zig");
const core_systems = @import("ecs/core/systems.zig");
const ccmp = @import("ecs/core/components.zig");
const input_systems = @import("ecs/input/systems.zig");
const icmp = @import("ecs/input/components.zig");
const scene_systems = @import("ecs/scene/systems.zig");
const scmp = @import("ecs/scene/components.zig");
const rs = @import("engine/resources.zig");

const Root = struct {};
const Btn = struct {};

pub fn main() !void {
    //std.debug.print("{}", .{ scene_systems.scene_components });

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1024;
    const screenHeight = 650;

    rl.InitWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.CloseWindow(); // Close window and OpenGL context

    rl.SetTargetFPS(144); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const allocator = std.heap.page_allocator;
    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var res = rs.Resources.init(arena);

    var reg = ecs.Registry.init(arena);
    defer reg.deinit();

    //debug init

    const path = try std.fs.path.join(arena, &.{ "resources", "scenes", "editor_gui.json" });
    //const path = try std.fs.path.join(arena, &.{ "resources", "scenes", "text_input_test_scene.json" });
    var scene_entity = reg.create();
    reg.add(scene_entity, scmp.SceneResource { .scene_path = path });
    reg.add(scene_entity, rcmp.AttachTo { .target = null });

    //debug init end

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

        try scene_systems.loadScene(&reg, arena, &res);
        try render_systems.loadResource(&reg, &res);
        try render_systems.attachTo(&reg, arena);
        try render_systems.updateGlobalTransform(&reg);
        render_systems.setSolidRectColor(&reg);
        render_systems.setTextParams(&reg);
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