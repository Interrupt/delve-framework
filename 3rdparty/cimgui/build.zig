const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_cimgui = b.dependency("cimgui", .{});
    const dep_imgui = b.dependency("imgui", .{});

    // create file tree for cimgui and imgui
    const wf = b.addNamedWriteFiles("cimgui");
    _ = wf.addCopyDirectory(dep_cimgui.path(""), "", .{});
    _ = wf.addCopyDirectory(dep_imgui.path(""), "imgui", .{});
    const root = wf.getDirectory();

    // build cimgui as C/C++ library
    const lib_cimgui = b.addStaticLibrary(.{
        .name = "cimgui_clib",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib_cimgui.linkLibCpp();
    lib_cimgui.addCSourceFiles(.{
        .root = root,
        .files = &.{
            b.pathJoin(&.{"cimgui.cpp"}),
            b.pathJoin(&.{ "imgui", "imgui.cpp" }),
            b.pathJoin(&.{ "imgui", "imgui_widgets.cpp" }),
            b.pathJoin(&.{ "imgui", "imgui_draw.cpp" }),
            b.pathJoin(&.{ "imgui", "imgui_tables.cpp" }),
            b.pathJoin(&.{ "imgui", "imgui_demo.cpp" }),
        },
    });
    lib_cimgui.addIncludePath(root);

    // make cimgui available as artifact, this then allows to inject
    // the Emscripten include path in another build.zig
    b.installArtifact(lib_cimgui);

    // lib compilation depends on file tree
    lib_cimgui.step.dependOn(&wf.step);

    // translate-c the cimgui.h file
    // NOTE: always run this with the host target, that way we don't need to inject
    // the Emscripten SDK include path into the translate-C step when building for WASM
    const cimgui_h = dep_cimgui.path("cimgui.h");
    const translateC = b.addTranslateC(.{
        .root_source_file = cimgui_h,
        .target = b.host,
        .optimize = optimize,
    });
    translateC.defineCMacroRaw("CIMGUI_DEFINE_ENUMS_AND_STRUCTS=\"\"");
    const entrypoint = translateC.getOutput();

    // build cimgui as a module with the header file as the entrypoint
    const mod_cimgui = b.addModule("cimgui", .{
        .root_source_file = entrypoint,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    mod_cimgui.linkLibrary(lib_cimgui);
}
