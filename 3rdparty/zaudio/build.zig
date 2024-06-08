const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    _ = b.addModule("root", .{
        .root_source_file = .{ .path = "src/zaudio.zig" },
    });

    const miniaudio = b.addStaticLibrary(.{
        .name = "miniaudio",
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(miniaudio);

    miniaudio.addIncludePath(.{ .path = "libs/miniaudio" });
    miniaudio.linkLibC();

    const system_sdk = b.dependency("system_sdk", .{});

    if (target.result.isWasm()) {
        // If we have a defined sysroot use that include path too
        if (b.sysroot) |sysroot| {
            const include_path = std.fs.path.join(b.allocator, &.{ sysroot, "include" }) catch {
                return;
            };
            defer b.allocator.free(include_path);
            miniaudio.addIncludePath(.{ .path = include_path });
        }
    } else if (target.result.os.tag == .macos) {
        miniaudio.addFrameworkPath(.{ .path = system_sdk.path("macos12/System/Library/Frameworks").getPath(b) });
        miniaudio.addSystemIncludePath(.{ .path = system_sdk.path("macos12/usr/include").getPath(b) });
        miniaudio.addLibraryPath(.{ .path = system_sdk.path("macos12/usr/lib").getPath(b) });
        miniaudio.linkFramework("CoreAudio");
        miniaudio.linkFramework("CoreFoundation");
        miniaudio.linkFramework("AudioUnit");
        miniaudio.linkFramework("AudioToolbox");
    } else if (target.result.os.tag == .linux) {
        miniaudio.linkSystemLibrary("pthread");
        miniaudio.linkSystemLibrary("m");
        miniaudio.linkSystemLibrary("dl");
    }

    miniaudio.addCSourceFile(.{
        .file = .{ .path = "src/zaudio.c" },
        .flags = &.{if (target.result.isWasm()) "-std=gnu99" else "-std=c99"},
    });

    miniaudio.addCSourceFile(.{
        .file = .{ .path = "libs/miniaudio/miniaudio.c" },
        .flags = &.{
            // "-DMA_NO_WEBAUDIO",
            "-DMA_NO_ENCODING",
            "-DMA_NO_NULL",
            "-DMA_NO_JACK",
            "-DMA_NO_DSOUND",
            "-DMA_NO_WINMM",
            "-fno-sanitize=undefined",
            if (target.result.isWasm()) "-std=gnu99" else "-std=c99",
            if (target.result.os.tag == .macos) "-DMA_NO_RUNTIME_LINKING" else "",
        },
    });

    const test_step = b.step("test", "Run zaudio tests");

    const tests = b.addTest(.{
        .name = "zaudio-tests",
        .root_source_file = .{ .path = "src/zaudio.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(tests);

    tests.linkLibrary(miniaudio);

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
