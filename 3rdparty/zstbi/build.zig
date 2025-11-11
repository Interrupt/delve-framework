const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const zstbi = b.addModule("root", .{
        .root_source_file = b.path("src/zstbi.zig"),
    });

    zstbi.addIncludePath(b.path("libs/stbi"));
    if (optimize == .Debug) {
        // TODO: Workaround for Zig bug.
        zstbi.addCSourceFile(.{
            .file = b.path("src/zstbi.c"),
            .flags = &.{
                "-std=c99",
                "-fno-sanitize=undefined",
                "-g",
                "-O0",
            },
        });
    } else {
        zstbi.addCSourceFile(.{
            .file = b.path("src/zstbi.c"),
            .flags = &.{
                "-std=c99",
                "-fno-sanitize=undefined",
            },
        });
    }

    // [DelveFramework] Fixing emscripten build bug
    // if (target.result.os.tag != .emscripten) {
    //     zstbi.addIncludePath(.{
    //         .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "/include" }),
    //     });
    // } else {
    //     zstbi.link_libc = true;
    // }
    zstbi.link_libc = true;

    const test_step = b.step("test", "Run zstbi tests");

    const tests = b.addTest(.{
        .name = "zstbi-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zstbi.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("zstbi", zstbi);
    b.installArtifact(tests);

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
