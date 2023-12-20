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

const ClearInput = struct {};
const Tag = struct {};

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

    const inp = reg.create();
    reg.add(inp, icmp.MousePositionTracker {});
    reg.add(inp, icmp.MouseButtonTracker { .button = rl.MOUSE_BUTTON_LEFT });
    reg.add(inp, icmp.TapTracker { .delay = 0.3 });

    const inp1 = reg.create();
    reg.add(inp1, ClearInput { });
    reg.add(inp1, icmp.KeyInputTracker { .key = rl.KEY_D });

    const path = try std.fs.path.join(arena, &.{ "resources", "atlases", "star.json" });

    var timer = try std.time.Timer.start();
    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        
        const dt = @as(f32, @floatFromInt(timer.read())) / @as(f32, @floatFromInt(std.time.ns_per_s));
        timer.reset();

        var view1 = reg.view(.{ ClearInput, icmp.InputPressed }, .{});
        var iter1 = view1.entityIterator();
        while (iter1.next()) |_| {
            var del_view = reg.view(.{ Tag }, .{ ccmp.Destroyed });
            var del_iter = del_view.entityIterator();
            while (del_iter.next()) |del_entity| {
                reg.add(del_entity, ccmp.Destroyed {});
            }
        }

        var view = reg.view(.{ icmp.MousePositionInput, icmp.InputTap }, .{});
        var iter = view.entityIterator();
        while (iter.next()) |entity| {
            const mpos = reg.getConst(icmp.MousePositionInput, entity);

            const e = reg.create();
            reg.add(e, rcmp.Resource { .atlas_path = path, .sprite = "star" });
            reg.add(e, rcmp.Position { .x = @as(f32, @floatFromInt(mpos.x)), .y = @as(f32, @floatFromInt(mpos.y)) });
            reg.add(e, rcmp.AttachTo { .target = null });
            reg.add(e, rcmp.SpriteOffset { .x = 32, .y = 32 });
            reg.add(e, ccmp.Timer { .time = 2 });
            reg.add(e, ccmp.DestroyByTimer {});
            reg.add(e, Tag {});
        }

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