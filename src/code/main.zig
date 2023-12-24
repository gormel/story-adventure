const std = @import("std");
const rl = @import("raylib");
const ecs = @import("zig-ecs");
const render_systems = @import("ecs/render/systems.zig");
const rcmp = @import("ecs/render/components.zig");
const core_systems = @import("ecs/core/systems.zig");
const ccmp = @import("ecs/core/components.zig");
const input_systems = @import("ecs/input/systems.zig");
const icmp = @import("ecs/input/components.zig");
const rs = @import("engine/resources.zig");

const Root = struct {};
const Btn = struct {};

pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

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

    var render_list = std.ArrayList(ecs.Entity).init(arena);

    //debug init

    const path = try std.fs.path.join(arena, &.{ "resources", "atlases", "star.json" });

    const root_ety = reg.create();
    reg.add(root_ety, rcmp.AttachTo { .target = null });
    reg.add(root_ety, rcmp.Position { .x = screenWidth / 2, .y = screenHeight / 2 });
    reg.add(root_ety, rcmp.Rotation { .a = 0 });
    reg.add(root_ety, Root {});

    const btn1_ety = reg.create();
    reg.add(btn1_ety, rcmp.Resource { .atlas_path = path, .sprite = "star" });
    reg.add(btn1_ety, rcmp.AttachTo { .target = root_ety });
    reg.add(btn1_ety, rcmp.Position { .x = 64, .y = 0 });
    reg.add(btn1_ety, rcmp.SpriteOffset { .x = 32, .y = 32 });
    reg.add(btn1_ety, icmp.MouseOverTracker { .rect = rl.Rectangle { .x = -32, .y = -32, .width = 64, .height = 64 } });
    reg.add(btn1_ety, icmp.MouseButtonTracker { .button = rl.MOUSE_BUTTON_LEFT });
    reg.add(btn1_ety, Btn {});

    const btn2_ety = reg.create();
    reg.add(btn2_ety, rcmp.Resource { .atlas_path = path, .sprite = "star" });
    reg.add(btn2_ety, rcmp.AttachTo { .target = root_ety });
    reg.add(btn2_ety, rcmp.Position { .x = -64, .y = 0 });
    reg.add(btn2_ety, rcmp.SpriteOffset { .x = 32, .y = 32 });
    reg.add(btn1_ety, icmp.MouseOverTracker { .rect = rl.Rectangle { .x = -32, .y = -32, .width = 64, .height = 64 } });
    reg.add(btn2_ety, icmp.MouseButtonTracker { .button = rl.MOUSE_BUTTON_LEFT });
    reg.add(btn2_ety, Btn {});

    //debug init end

    var timer = try std.time.Timer.start();
    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        
        const dt = @as(f32, @floatFromInt(timer.read())) / @as(f32, @floatFromInt(std.time.ns_per_s));
        timer.reset();

        //debug logic
        
        var rt_view = reg.view(.{ rcmp.Rotation, Root }, .{ rcmp.UpdateGlobalTransform });
        var rt_iter = rt_view.entityIterator();
        while (rt_iter.next()) |entity| {
            var rot = rt_view.get(rcmp.Rotation, entity);
            rot.a += 0 * dt;
            reg.add(entity, rcmp.UpdateGlobalTransform {});
        }

        var prs_view = reg.view(.{ Btn, icmp.MouseOver }, .{});
        var prs_iter = prs_view.entityIterator();
        while (prs_iter.next()) |entity| {
            std.debug.print("Pressed: {0}", .{ entity });
        }

        //debug logic end

        input_systems.capture(&reg, dt);

        core_systems.timer(&reg, dt);
        core_systems.destroy_by_timer(&reg);

        try render_systems.load_resource(&reg, &res);
        try render_systems.attach_to(&reg, arena);
        try render_systems.update_global_transform(&reg, &render_list, arena);

        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.WHITE);

        try render_systems.render_sprite(&reg, &render_list);

        try render_systems.destroy_children(&reg);
        //destroy triggers
        core_systems.destroy(&reg);
    }
}