const std = @import("std");
const rl = @import("raylib.zig");
const ecs = @import("zig-ecs");

pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.InitWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.CloseWindow(); // Close window and OpenGL context

    const exe_path = try std.fs.selfExeDirPathAlloc(std.heap.page_allocator);
    const tex_path = try std.fs.path.join(std.heap.page_allocator , &[_][] const u8 { exe_path, "resources", "textures", "star.png" });

    const tex = rl.LoadTexture(tex_path.ptr);

    const frameWidth: f32 = @floatFromInt(@as(i32, tex.width));
    const frameHeight: f32 = @floatFromInt(@as(i32, tex.height));

    // Source rectangle (part of the texture to use for drawing)
    const sourceRec = rl.Rectangle { .x = 0.0, .y = 0.0, .width = frameWidth, .height = frameHeight };

    // Destination rectangle (screen rectangle where drawing part of texture)
    const destRec = rl.Rectangle { .x = screenWidth/2.0, .y = screenHeight / 2.0, .width = frameWidth * 2.0, .height = frameHeight * 2.0 };

    // Origin of the texture (rotation/scale point), it's relative to destination rectangle size
    const origin = rl.Vector2 { .x = frameWidth, .y = frameHeight };

    rl.SetTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    var reg = ecs.Registry.init(std.heap.c_allocator);
    defer reg.deinit();

    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.WHITE);

        rl.DrawTexturePro(tex, sourceRec, destRec, origin, 0.3, rl.WHITE);
        //----------------------------------------------------------------------------------
    }
}
