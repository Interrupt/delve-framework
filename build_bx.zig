const std = @import("std");

const bx_path = "3rdparty/bx/";

pub fn link(exe: *std.build.LibExeObjStep) void {
    const lib = buildLibrary(exe);
    addBxIncludes(exe);
    exe.linkLibrary(lib);
}

fn buildLibrary(exe: *std.build.LibExeObjStep) *std.build.LibExeObjStep {
    const cxx_options = [_][]const u8{
        "-fno-strict-aliasing",
        "-fno-exceptions",
        "-fno-rtti",
        "-ffast-math",
        "-DBX_CONFIG_DEBUG",
    };

    const bx_lib = exe.step.owner.addStaticLibrary(.{ .name = "bx", .target = exe.target, .optimize = exe.optimize});

    addBxIncludes(bx_lib);
    bx_lib.addIncludePath(.{ .path = bx_path ++ "3rdparty/"});
    if (bx_lib.target.isDarwin()) {
        bx_lib.linkFramework("CoreFoundation");
        bx_lib.linkFramework("Foundation");
    }
    bx_lib.addCSourceFile(.{ .file = .{ .path = bx_path ++ "src/amalgamated.cpp"}, .flags = &cxx_options});
    bx_lib.want_lto = false;
    bx_lib.linkSystemLibrary("c");
    bx_lib.linkSystemLibrary("c++");

    const bx_lib_artifact = exe.step.owner.addInstallArtifact(bx_lib, .{});
    exe.step.owner.getInstallStep().dependOn(&bx_lib_artifact.step);
    return bx_lib;
}

pub fn addBxIncludes(exe: *std.build.LibExeObjStep) void {
    var compat_include: []const u8 = "";

    if (exe.target.isWindows()) {
        compat_include = thisDir() ++ "/" ++ bx_path ++ "include/compat/mingw/";
    } else if (exe.target.isDarwin()) {
        compat_include = thisDir() ++ "/" ++ bx_path ++ "include/compat/osx/";
    }

    exe.addIncludePath(.{ .path = compat_include});
    exe.addIncludePath(.{ .path = thisDir() ++ "/" ++ bx_path ++ "include/"});
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
