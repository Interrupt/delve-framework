const std = @import("std");

const bx = @import("build_bx.zig");
const bimg = @import("build_bimg.zig");

const bgfx_path = "3rdparty/bgfx/";

var framework_dir: ?[]u8 = null;

pub fn link(exe: *std.build.LibExeObjStep) void {
    const lib = buildLibrary(exe);
    addBgfxIncludes(exe);
    exe.linkLibrary(lib);
}

fn buildLibrary(exe: *std.build.LibExeObjStep) *std.build.LibExeObjStep {
    const cxx_options = [_][]const u8{
        "-fno-strict-aliasing",
        "-fno-exceptions",
        "-fno-rtti",
        "-ffast-math",
        "-DBX_CONFIG_DEBUG",
        "-DBGFX_CONFIG_USE_TINYSTL=0",
        "-DBGFX_CONFIG_MULTITHREADED=0", // OSX does not support multithreaded rendering
    };

    var bgfx_module = exe.step.owner.createModule(.{
        .source_file = .{ .path = thisDir() ++ "/" ++ bgfx_path ++ "bindings/zig/bgfx.zig"},
    });

    const bgfx_lib = exe.step.owner.addStaticLibrary(.{
        .name = "bgfx",
        .target = exe.target,
        .optimize = exe.optimize,
    });

    exe.addModule("bgfx", bgfx_module);

    bgfx_lib.addIncludePath(.{ .path = bgfx_path ++ "include/"});
    bgfx_lib.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/"});
    bgfx_lib.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/directx-headers/include/directx/"});
    bgfx_lib.addIncludePath(.{ .path = bgfx_path ++ "3rdparty/khronos/"});
    bgfx_lib.addIncludePath(.{ .path = bgfx_path ++ "src/"});

    if (bgfx_lib.target.isDarwin()) {
        bgfx_lib.addCSourceFile(.{ .file = .{ .path = bgfx_path ++ "src/amalgamated.mm"}, .flags = &cxx_options});
        bgfx_lib.linkFramework("Foundation");
        bgfx_lib.linkFramework("CoreFoundation");
        bgfx_lib.linkFramework("Cocoa");
        bgfx_lib.linkFramework("QuartzCore");
    } else {
        bgfx_lib.addCSourceFile(.{ .file = .{ .path = bgfx_path ++ "src/amalgamated.cpp"}, .flags = &cxx_options});
    }

    bgfx_lib.want_lto = false;
    bgfx_lib.linkSystemLibrary("c");
    bgfx_lib.linkSystemLibrary("c++");
    bx.link(bgfx_lib);
    bimg.link(bgfx_lib);

    const bgfx_lib_artifact = exe.step.owner.addInstallArtifact(bgfx_lib, .{});
    exe.step.owner.getInstallStep().dependOn(&bgfx_lib_artifact.step);

    return bgfx_lib;
}

fn addBgfxIncludes(exe: *std.build.LibExeObjStep) void {
    exe.addIncludePath(.{ .path = thisDir() ++ "/" ++ bgfx_path ++ "include/"});
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
