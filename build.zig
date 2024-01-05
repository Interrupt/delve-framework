const std = @import("std");
const sokol = @import("3rdparty/sokol-zig/build.zig");
const zaudio = @import("3rdparty/zaudio/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "delve-framework",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add Ziglua module
    const ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("ziglua", ziglua.module("ziglua"));
    exe.linkLibrary(ziglua.artifact("lua"));

    // Include Sokol from submodule
    const sokol_build = sokol.buildSokol(b, target, optimize, .{}, "3rdparty/sokol-zig/");
    exe.linkLibrary(sokol_build);
    exe.addAnonymousModule("sokol", .{ .source_file = .{ .path = "3rdparty/sokol-zig/src/sokol/sokol.zig" } });

    // Add sdb_image single header library for image file format support
    exe.addCSourceFile(.{ .file = .{ .cwd_relative = "libs/stb_image-2.28/stb_image_impl.c"}, .flags = &[_][]const u8{"-std=c99"}});
    exe.addIncludePath(.{ .path = "libs/stb_image-2.28"});

    // Add zaudio library
    const zaudio_pkg = zaudio.package(b, target, optimize, .{});
    zaudio_pkg.link(exe);

    const install_exe = b.addInstallArtifact(exe, .{});
    b.getInstallStep().dependOn(&install_exe.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
