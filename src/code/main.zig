const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const render_systems = @import("ecs/render/systems.zig");
const core_systems = @import("ecs/core/systems.zig");
const rcmp = @import("ecs/render/components.zig");
const ccmp = @import("ecs/core/components.zig");
const rs = @import("engine/resources.zig");

pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.InitWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
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

    const path = try std.fs.path.join(arena, &.{ "resources", "atlases", "star.json" });

    const e = reg.create();
    reg.add(e, rcmp.Resource { .atlas_path = path, .sprite = "star" });
    reg.add(e, rcmp.Position { .x = screenWidth / 2, .y = screenHeight / 2 });
    reg.add(e, rcmp.Rotation { .a = 0 });
    reg.add(e, rcmp.SpriteOffset { .x = 32, .y = 32 });

    var timer = try std.time.Timer.start();
    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        
        //const dt = timer.read();
        timer.reset();

        try render_systems.load_resource(&reg, &res);

        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.WHITE);

        render_systems.render_sprite(&reg);

        core_systems.destroy(&reg);
    }
}