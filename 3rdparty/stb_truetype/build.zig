const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const root = b.addModule("root", .{
        .root_source_file = b.path("src/stb_truetype.zig"),
    });

    root.addIncludePath(b.path("libs"));

    const lib = b.addStaticLibrary(.{
        .target = target,
        .optimize = optimize,
        .name = "stb_truetype",
    });

    lib.addCSourceFile(.{
        .file = b.path("src/stb_truetype.c"),
        .flags = &.{
            "-std=c99",
        },
    });

    lib.addIncludePath(b.path("libs"));
    lib.linkLibC();

    b.installArtifact(lib);

    const test_step = b.step("test", "Run stb_truetype tests");

    const tests = b.addTest(.{
        .name = "stb-truetype-tests",
        .root_source_file = b.path("src/stb_truetype.zig"),
        .target = target,
        .optimize = optimize,
    });

    tests.linkLibrary(lib);
    tests.addIncludePath(b.path("libs"));
    b.installArtifact(tests);

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
