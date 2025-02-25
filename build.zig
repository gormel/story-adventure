const std = @import("std");

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

    const res_source = b.pathJoin(&.{ "src", "resources" });
    const res_install_subdir = b.pathJoin(&.{ "bin", "resources" });
    const add_resources = b.addInstallDirectory(.{
        .source_dir = b.path(res_source),
        .install_dir = .{ .custom = "" },
        .install_subdir = res_install_subdir,
    });
    exe.step.dependOn(&add_resources.step);
    
    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    const ecs = b.dependency("zig_ecs", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zig-ecs", ecs.module("zig-ecs"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
