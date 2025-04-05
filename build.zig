const std = @import("std");

fn addAssetsOption(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode
) !void {
    var options = b.addOptions();

    var files = std.ArrayList([]const u8).init(b.allocator);
    defer files.deinit();

    var filedatas = std.ArrayList([]const u8).init(b.allocator);
    defer filedatas.deinit();

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fs.cwd().realpath("src/code/assets", buf[0..]);

    var dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
    defer dir.close();

    var it = try dir.walk(b.allocator);
    while (try it.next()) |entry| {
        if (entry.kind != .file) {
            continue;
        }

        const fp = try entry.dir.openFile(entry.basename, .{});
        defer fp.close();
        
        const meta = try fp.metadata();
        const fbuf: [] u8 = try b.allocator.alloc(u8, meta.size());
        defer b.allocator.free(fbuf);

        const read = try fp.readAll(fbuf);

        try files.append(b.dupe(entry.path));
        try filedatas.append(b.dupe(fbuf[0..read]));
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

    exe.linkLibrary(raylib_artifact);
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

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "story-adventure",
        .root_source_file = b.path("src/code/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const strip = b.option(
        bool,
        "strip",
        "Strip debug info to reduce binary size, defaults to false",
    ) orelse false;
    exe.root_module.strip = strip;

    addAssetsOption(b, exe, target, optimize) catch |e| { std.log.err("ERROR: Cannot load asset {!}", .{ e }); };
    addRaylib(b, exe, target, optimize);
    addEcs(b, exe, target, optimize);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
