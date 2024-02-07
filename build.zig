const std = @import("std");
const sokol = @import("3rdparty/sokol-zig/build.zig");
const zaudio = @import("3rdparty/zaudio/build.zig");
const zmesh = @import("3rdparty/zmesh/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    });

    const sokol_module = b.createModule(.{
        .source_file = .{ .path = "3rdparty/sokol-zig/src/sokol/sokol.zig" },
    });

    const zaudio_pkg = zaudio.package(b, target, optimize, .{});
    const zmesh_pkg = zmesh.package(b, target, optimize, .{});

    const delve_module = b.addModule("delve", .{
        .source_file = .{ .path = "src/framework/delve.zig" },
        .dependencies = &.{
            .{ .name = "ziglua", .module = ziglua.module("ziglua") },
            .{ .name = "sokol", .module = sokol_module },
            .{ .name = "zaudio", .module = zaudio_pkg.zaudio },
            .{ .name = "zmesh", .module = zmesh_pkg.zmesh },
        },
    });

    // Delve library artifact
    const lib_opts = .{
        .name = "delve",
        .target = target,
        .optimize = optimize,
    };

    // make the Delve library as a static lib
    const lib = b.addStaticLibrary(lib_opts);
    makeDelveLibrary(b, lib, target, optimize);
    b.installArtifact(lib);

    buildExample(b, "audio", target, optimize, delve_module, lib);
    buildExample(b, "sprites", target, optimize, delve_module, lib);
    buildExample(b, "sprite-animation", target, optimize, delve_module, lib);
    buildExample(b, "clear", target, optimize, delve_module, lib);
    buildExample(b, "collision", target, optimize, delve_module, lib);
    buildExample(b, "debugdraw", target, optimize, delve_module, lib);
    buildExample(b, "easing", target, optimize, delve_module, lib);
    buildExample(b, "forest", target, optimize, delve_module, lib);
    buildExample(b, "framepacing", target, optimize, delve_module, lib);
    buildExample(b, "lua", target, optimize, delve_module, lib);
    buildExample(b, "meshbuilder", target, optimize, delve_module, lib);
    buildExample(b, "meshes", target, optimize, delve_module, lib);
    buildExample(b, "stresstest", target, optimize, delve_module, lib);

    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/framework/delve.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

pub fn makeDelveLibrary(b: *std.Build, step: *std.Build.CompileStep, target: anytype, optimize: anytype) void {
    step.addCSourceFile(.{ .file = .{ .path = "libs/stb_image-2.28/stb_image_impl.c" }, .flags = &[_][]const u8{"-std=c99"} });
    step.addIncludePath(.{ .path = "libs/stb_image-2.28" });

    const sokol_build = sokol.buildSokol(b, target, optimize, .{}, "3rdparty/sokol-zig/");
    step.linkLibrary(sokol_build);

    const zaudio_pkg = zaudio.package(b, target, optimize, .{});
    zaudio_pkg.link(step);

    const zmesh_pkg = zmesh.package(b, target, optimize, .{});
    zmesh_pkg.link(step);

    const ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    });
    step.linkLibrary(ziglua.artifact("lua"));

    // let users of our library get access to some headers
    step.installHeader("libs/stb_image-2.28/stb_image.h", "stb_image.h");
    step.installLibraryHeaders(ziglua.artifact("lua"));
}

pub fn buildExample(b: *std.Build, comptime name: []const u8, target: anytype, optimize: anytype, delve_module: *std.Build.Module, lib: *std.Build.CompileStep) void {
    const src_main = "src/examples/" ++ name ++ ".zig";

    const example = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = src_main },
        .target = target,
        .optimize = optimize,
    });

    example.addModule("delve", delve_module);
    example.linkLibrary(lib);

    b.installArtifact(example);
    const run = b.addRunArtifact(example);

    b.step("run-" ++ name, "Run " ++ name).dependOn(&run.step);
}
