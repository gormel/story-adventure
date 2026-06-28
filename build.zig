const std = @import("std");

fn addAssetsOption(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode
) !void {
    var options = b.addOptions();

    var files = std.ArrayList([]const u8).empty;
    defer files.deinit(b.allocator);

    var filedatas = std.ArrayList([]const u8).empty;
    defer filedatas.deinit(b.allocator);

    const path = b.path("src/code/assets/");

    var threaded: std.Io.Threaded = .init(b.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var dir = try std.Io.Dir.openDirAbsolute(io, path.getPath(b), .{ .iterate = true });
    defer dir.close(io);

    var it = try dir.walk(b.allocator);
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) {
            continue;
        }

        const fp = try entry.dir.openFile(io, entry.basename, .{});
        defer fp.close(io);
        
        const stat = try fp.stat(io);
        const fbuf: [] u8 = try b.allocator.alloc(u8, stat.size);
        defer b.allocator.free(fbuf);

        const read = try entry.dir.readFile(io, entry.basename, fbuf);

        try files.append(b.allocator, b.dupe(entry.path));
        try filedatas.append(b.allocator, b.dupe(read));
    }

    options.addOption([]const []const u8, "filenames", files.items);
    options.addOption([]const []const u8, "filedatas", filedatas.items);
    exe.step.dependOn(&options.step);

    const module = b.addModule("assets", .{
        .root_source_file = options.getOutput(),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("assets", module);
}

fn addRaylib(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode
) void {
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    exe.root_module.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);
}

fn addEcs(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode
) void {
    const ecs = b.dependency("zig_ecs", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("zig-ecs", ecs.module("zig-ecs"));
}

fn addAstar(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode
) void {
    const astar = b.dependency("zig_astar", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("zig-astar", astar.module("zig-astar"));
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "story-adventure",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/code/main.zig"),
            .target = target,
            .optimize = optimize
        }),
    });

    const strip = b.option(
        bool,
        "strip",
        "Strip debug info to reduce binary size, defaults to false",
    ) orelse false;
    exe.root_module.strip = strip;

    addAssetsOption(b, exe, target, optimize) catch |e| { std.log.err("ERROR: Cannot load asset: {any}", .{ e }); };
    addRaylib(b, exe, target, optimize);
    addEcs(b, exe, target, optimize);
    addAstar(b, exe, target, optimize);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
