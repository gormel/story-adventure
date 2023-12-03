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

    var render_list = std.ArrayList(ecs.Entity).init(arena);

    const path = try std.fs.path.join(arena, &.{ "resources", "atlases", "star.json" });

    const r = reg.create();
    reg.add(r, rcmp.Position { .x = screenWidth / 2, .y = screenHeight / 2 });
    reg.add(r, rcmp.Rotation { .a = 45 });
    reg.add(r, rcmp.Scale { .x = 2, .y = 1 });
    reg.add(r, rcmp.AttachTo { .target = null });

    const e = reg.create();
    reg.add(e, rcmp.Resource { .atlas_path = path, .sprite = "star" });
    reg.add(e, rcmp.Position { .x = -32, .y = 0 });
    reg.add(e, rcmp.SpriteOffset { .x = 32, .y = 32 });
    reg.add(e, rcmp.AttachTo { .target = r });
    //reg.add(e, rcmp.Scale { .x = 0.5, .y = 1 });

    const e1 = reg.create();
    reg.add(e1, rcmp.Resource { .atlas_path = path, .sprite = "star" });
    reg.add(e1, rcmp.Position { .x = 32, .y = 0 });
    reg.add(e1, rcmp.SpriteOffset { .x = 32, .y = 32 });
    reg.add(e1, rcmp.AttachTo { .target = r });
    reg.add(e1, rcmp.Scale { .x = 0.5, .y = 1 });

    var timer = try std.time.Timer.start();
    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        
        const dt = @as(f32, @floatFromInt(timer.read())) / @as(f32, @floatFromInt(std.time.ns_per_s));
        timer.reset();

        var rotation = reg.get(rcmp.Rotation, r);
        rotation.a += 90 * dt;
        reg.add(r, rcmp.UpdateGlobalTransform {});
        std.log.info("0: {}", .{rotation.a});

        try render_systems.load_resource(&reg, &res);
        try render_systems.attach_to(&reg, arena);
        try render_systems.update_global_transform(&reg, &render_list, arena);

        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.WHITE);

        try render_systems.render_sprite(&reg, &render_list);

        try render_systems.destroy_children(&reg);
        core_systems.destroy(&reg);
    }
}