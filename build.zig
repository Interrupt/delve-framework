const std = @import("std");
const sokol = @import("sokol");
const zaudio = @import("zaudio");
const zmesh = @import("zmesh");

const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    // special case handling for native vs web build
    if (target.result.isWasm()) {
        try buildWeb(b, target, optimize, dep_sokol);
    } else {
        try buildNative(b, target, optimize, dep_sokol);
    }
}

// this is the regular build for all native platforms, nothing surprising here
fn buildNative(b: *Build, target: Build.ResolvedTarget, optimize: OptimizeMode, dep_sokol: *Build.Dependency) !void {
    const my_template = b.addExecutable(.{
        .name = "my_template",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
    });
    my_template.root_module.addImport("sokol", dep_sokol.module("sokol"));
    try setup_links(b, target, optimize, my_template);

    b.installArtifact(my_template);
    const run = b.addRunArtifact(my_template);
    b.step("run", "Run my_template").dependOn(&run.step);
}

// for web builds, the Zig code needs to be built into a library and linked with the Emscripten linker
fn buildWeb(b: *Build, target: Build.ResolvedTarget, optimize: OptimizeMode, dep_sokol: *Build.Dependency) !void {
    const my_template = b.addStaticLibrary(.{
        .name = "my_template",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
    });
    my_template.root_module.addImport("sokol", dep_sokol.module("sokol"));
    try setup_links(b, target, optimize, my_template);

    // create a build step which invokes the Emscripten linker
    const emsdk = dep_sokol.builder.dependency("emsdk", .{});
    const link_step = try sokol.emLinkStep(b, .{
        .lib_main = my_template,
        .target = target,
        .optimize = optimize,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .use_emmalloc = true,
        .use_filesystem = false,
        .shell_file_path = dep_sokol.path("src/sokol/web/shell.html").getPath(b),
    });
    // ...and a special run step to start the web build output via 'emrun'
    const run = sokol.emRunStep(b, .{ .name = "my_template", .emsdk = emsdk });
    run.step.dependOn(&link_step.step);
    b.step("run", "Run my_template").dependOn(&run.step);
}

fn setup_links(b: *Build, target: Build.ResolvedTarget, optimize: OptimizeMode, app: *Build.Step.Compile) !void {
    try append_libraries(b, target, optimize, app, "assets", "assets/assets.zig");

    try append_module(b, target, optimize, app, "ziglua");

    const zaudio_pkg = zaudio.package(b, target, optimize, .{});
    zaudio_pkg.link(app);

    const zmesh_pkg = zaudio.package(b, target, optimize, .{});
    zmesh_pkg.link(app);

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
}

fn append_libraries(b: *Build, target: Build.ResolvedTarget, optimize: OptimizeMode, app: *Build.Step.Compile, comptime name: []const u8, comptime src_path: []const u8) !void {
    const asset_lib = b.addStaticLibrary(.{
        .name = name,
        .root_source_file = .{ .path = src_path },
        .target = target,
        .optimize = optimize,
    });
    app.linkLibrary(asset_lib);
    b.installArtifact(asset_lib);
}

fn append_module(b: *Build, target: Build.ResolvedTarget, optimize: OptimizeMode, app: *Build.Step.Compile, comptime module_name: []const u8) !void {
    app.root_module.addImport(module_name, b.dependency(module_name, .{
        .target = target,
        .optimize = optimize,
    }).module(module_name));
}

pub fn makeDelveLibrary(b: *std.Build, step: *Build.Step.Compile, target: anytype, optimize: anytype) void {
    step.addCSourceFile(.{ .file = .{ .path = "libs/stb_image-2.28/stb_image_impl.c" }, .flags = &[_][]const u8{"-std=c99"} });
    step.addIncludePath(.{ .path = "libs/stb_image-2.28" });

    const sokol_options: sokol.LibSokolOptions = .{
        .optimize = optimize,
        .target = target,
    };
    const sokol_build = sokol.buildLibSokol(b, sokol_options);
    step.linkLibrary(sokol_build);
    step.root_module.linkLibrary(sokol_build);

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

// --------------------------------------------------------------------------
pub fn _build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    });

    const sokol_module = b.createModule(.{
        .root_source_file = .{ .path = "3rdparty/sokol-zig/src/sokol/sokol.zig" },
    });

    const zaudio_pkg = zaudio.package(b, target, optimize, .{});
    const zmesh_pkg = zmesh.package(b, target, optimize, .{});

    const delve_module = b.addModule("delve", .{
        .root_source_file = .{ .path = "src/framework/delve.zig" },
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
