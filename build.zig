const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "story-adventure",
        .root_source_file = .{ .path = "src/code/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const raylib_optimize = b.option(
        std.builtin.OptimizeMode,
        "raylib-optimize",
        "Prioritize performance, safety, or binary size (-O flag), defaults to value of optimize option",
    ) orelse optimize;

    const strip = b.option(
        bool,
        "strip",
        "Strip debug info to reduce binary size, defaults to false",
    ) orelse false;
    exe.strip = strip;


    const this_dir = std.fs.path.dirname(@src().file) orelse ".";
    const res_source = b.pathJoin(&.{ this_dir, "src", "resources" });
    const res_install_subdir = b.pathJoin(&.{ "bin", "resources" });
    const add_resources = b.addInstallDirectory(.{
        .source_dir = .{ .path = res_source },
        .install_dir = .{ .custom = "" },
        .install_subdir = res_install_subdir,
    });
    exe.step.dependOn(&add_resources.step);

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = raylib_optimize,
    });
    exe.linkLibrary(raylib_dep.artifact("raylib"));
    const raylib_path_fragment = b.pathJoin(&.{ "src", "code", "raylib.zig" });
    const raylib_module = b.addModule("raylib", .{ .source_file = .{ .path = raylib_path_fragment } });
    _ = exe.addModule("raylib", raylib_module);
    //exe.addPa

    const ecs = b.dependency("zig_ecs", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("zig-ecs", ecs.module("zig-ecs"));

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
