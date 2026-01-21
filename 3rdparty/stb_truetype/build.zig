const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const root_module = b.addModule("root", .{
        .root_source_file = b.path("src/stb_truetype.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "stb_truetype",
        .linkage = .static,
        .root_module = root_module,
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
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/stb_truetype.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    tests.linkLibrary(lib);
    tests.addIncludePath(b.path("libs"));
    b.installArtifact(tests);

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
