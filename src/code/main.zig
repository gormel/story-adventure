const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const render_systems = @import("ecs/render/systems.zig");
const rcmp = @import("ecs/render/components.zig");

pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.InitWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.CloseWindow(); // Close window and OpenGL context

    rl.SetTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    var reg = ecs.Registry.init(std.heap.c_allocator);
    defer reg.deinit();

    const exe_dir = try std.fs.selfExeDirPathAlloc(std.heap.page_allocator);
    const path = try std.fs.path.join(std.heap.page_allocator, &.{ exe_dir, "resources", "textures", "star.png" });

    const e = reg.create();
    reg.add(e, rcmp.Resource { .path = path });
    reg.add(e, rcmp.Position { .x = screenWidth / 2, .y = screenHeight / 2 });
    reg.add(e, rcmp.Rotation { .a = 0 });

    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        render_systems.load_resource(&reg);
        render_systems.rotate(&reg);

        // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.WHITE);

        render_systems.render(&reg);

        //----------------------------------------------------------------------------------
    }
}
