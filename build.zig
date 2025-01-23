const std = @import("std");
const Build = std.Build;
const builtin = @import("builtin");
const ziglua = @import("ziglua");
const sokol = @import("sokol");
const system_sdk = @import("system-sdk");
const fs = std.fs;
const log = std.log;

var target: Build.ResolvedTarget = undefined;
var optimize: std.builtin.OptimizeMode = undefined;

const ModuleImport = struct {
    module: *Build.Module,
    name: []const u8,
};
const BuildCollection = struct {
    add_imports: []const ModuleImport,
    link_libraries: []const *Build.Step.Compile,
};

pub fn build(b: *std.Build) !void {
    target = b.standardTargetOptions(.{});
    optimize = b.standardOptimizeOption(.{});

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
        .with_sokol_imgui = true,
    });

    const dep_ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
        .lang = .lua54,
        .can_use_jmp = !target.result.isWasm(),
    });

    const dep_zmesh = b.dependency("zmesh", .{
        .target = target,
        .optimize = optimize,
    });

    const dep_zaudio = b.dependency("zaudio", .{
        .target = target,
        .optimize = optimize,
    });

    const dep_zstbi = b.dependency("zstbi", .{
        .target = target,
        .optimize = optimize,
    });

    const dep_cimgui = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });

    const dep_stb_truetype = b.dependency("stb_truetype", .{
        .target = target,
        .optimize = optimize,
    });

    const dep_yamlz = b.dependency("ymlz", .{
        .target = target,
        .optimize = optimize,
    });

    // inject the cimgui header search path into the sokol C library compile step
    const cimgui_root = dep_cimgui.namedWriteFiles("cimgui").getDirectory();
    dep_sokol.artifact("sokol_clib").addIncludePath(cimgui_root);

    dep_stb_truetype.artifact("stb_truetype").addIncludePath(b.path("3rdparty/stb_truetype/libs"));

    const sokol_item = .{ .module = dep_sokol.module("sokol"), .name = "sokol" };
    const ziglua_item = .{ .module = dep_ziglua.module("ziglua"), .name = "ziglua" };
    const zmesh_item = .{ .module = dep_zmesh.module("root"), .name = "zmesh" };
    const zstbi_item = .{ .module = dep_zstbi.module("root"), .name = "zstbi" };
    const zaudio_item = .{ .module = dep_zaudio.module("root"), .name = "zaudio" };
    const cimgui_item = .{ .module = dep_cimgui.module("cimgui"), .name = "cimgui" };
    const stb_truetype_item = .{ .module = dep_stb_truetype.module("root"), .name = "stb_truetype" };
    const ymlz_item = .{ .module = dep_yamlz.module("root"), .name = "ymlz" };

    const delve_module_imports = [_]ModuleImport{
        sokol_item,
        zmesh_item,
        zstbi_item,
        zaudio_item,
        ziglua_item,
        cimgui_item,
        stb_truetype_item,
        ymlz_item,
    };

    const link_libraries = [_]*Build.Step.Compile{
        dep_zmesh.artifact("zmesh"),
        dep_zstbi.artifact("zstbi"),
        dep_zaudio.artifact("miniaudio"),
        dep_ziglua.artifact("lua"),
        dep_cimgui.artifact("cimgui_clib"),
        dep_stb_truetype.artifact("stb_truetype"),
    };

    const build_collection: BuildCollection = .{
        .add_imports = &delve_module_imports,
        .link_libraries = &link_libraries,
    };

    // Delve module
    const delve_mod = b.addModule("delve", .{
        .root_source_file = b.path("src/framework/delve.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Sokol module (exposed for using shader file outside of delve)
    try b.modules.put("sokol", dep_sokol.module("sokol"));

    for (build_collection.add_imports) |build_import| {
        delve_mod.addImport(build_import.name, build_import.module);
    }

    for (build_collection.link_libraries) |lib| {
        if (target.result.isWasm()) {
            // ensure these libs all depend on the emcc C lib
            lib.step.dependOn(&dep_sokol.artifact("sokol_clib").step);
        }

        delve_mod.linkLibrary(lib);
    }

    // For web builds, add the Emscripten system headers so C libraries can find the stdlib headers
    if (target.result.isWasm()) {
        const emsdk_include_path = getEmsdkSystemIncludePath(dep_sokol);
        delve_mod.addSystemIncludePath(emsdk_include_path);

        // add these new system includes to all the libs and modules
        for (build_collection.add_imports) |build_import| {
            build_import.module.addSystemIncludePath(emsdk_include_path);
        }

        for (build_collection.link_libraries) |lib| {
            lib.addSystemIncludePath(emsdk_include_path);
        }
    }

    // Delve Static Library artifact
    const delve_lib = b.addStaticLibrary(.{
        .target = target,
        .optimize = optimize,
        .name = "delve",
        .root_source_file = b.path("src/framework/delve.zig"),
    });

    b.installArtifact(delve_lib);

    // collection of all examples
    const examples = [_][]const u8{
        "audio",
        "sprites",
        "sprite-animation",
        "clear",
        "collision",
        "debugdraw",
        "easing",
        "fonts",
        "forest",
        "framepacing",
        "frustums",
        "imgui",
        "lighting",
        "lua",
        "meshbuilder",
        "meshes",
        "passes",
        "quakemap",
        "quakemdl",
        "rays",
        "skinned-meshes",
        "stresstest",
    };

    for (examples) |example_item| {
        try buildExample(b, example_item, delve_mod, delve_lib);
    }

    // add the build shaders run step, to update the baked in default shaders
    buildShaders(b);

    // TESTS
    const exe_tests = b.addTest(.{
        .root_source_file = b.path("src/framework/delve.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

fn buildExample(b: *std.Build, example: []const u8, delve_module: *Build.Module, delve_lib: *Build.Step.Compile) !void {
    const name: []const u8 = example;
    var root_source_buffer = [_]u8{undefined} ** 256;
    const root_source_file = try std.fmt.bufPrint(&root_source_buffer, "src/examples/{s}.zig", .{name});

    var app: *Build.Step.Compile = undefined;
    // special case handling for native vs web build
    if (target.result.isWasm()) {
        app = b.addStaticLibrary(.{
            .target = target,
            .optimize = optimize,
            .name = name,
            .root_source_file = b.path(root_source_file),
        });
    } else {
        app = b.addExecutable(.{
            .target = target,
            .optimize = optimize,
            .name = name,
            .root_source_file = b.path(root_source_file),
        });
    }

    app.root_module.addImport("delve", delve_module);
    app.linkLibrary(delve_lib);

    if (target.result.isWasm()) {
        const dep_sokol = b.dependency("sokol", .{
            .target = target,
            .optimize = optimize,
            .with_sokol_imgui = true,
        });

        // link with emscripten
        const link_step = try emscriptenLinkStep(b, app, dep_sokol);

        // and add a run step
        const run = emscriptenRunStep(b, example, dep_sokol);
        run.step.dependOn(&link_step.step);

        var option_buffer = [_]u8{undefined} ** 100;
        const run_name = try std.fmt.bufPrint(&option_buffer, "run-{s}", .{name});
        var description_buffer = [_]u8{undefined} ** 200;
        const descr_name = try std.fmt.bufPrint(&description_buffer, "run {s}", .{name});
        b.step(run_name, descr_name).dependOn(&run.step);
    } else {
        b.installArtifact(app);
        const run = b.addRunArtifact(app);
        var option_buffer = [_]u8{undefined} ** 100;
        const run_name = try std.fmt.bufPrint(&option_buffer, "run-{s}", .{name});
        var description_buffer = [_]u8{undefined} ** 200;
        const descr_name = try std.fmt.bufPrint(&description_buffer, "run {s}", .{name});

        b.step(run_name, descr_name).dependOn(&run.step);
    }
}

pub fn emscriptenLinkStep(b: *Build, app: *Build.Step.Compile, dep_sokol: *Build.Dependency) !*Build.Step.InstallDir {
    app.defineCMacro("__EMSCRIPTEN__", "1");

    const emsdk = dep_sokol.builder.dependency("emsdk", .{});

    // Add the Emscripten system include path for the app too
    const emsdk_include_path = emsdk.path("upstream/emscripten/cache/sysroot/include");
    app.addSystemIncludePath(emsdk_include_path);

    return try sokol.emLinkStep(b, .{
        .lib_main = app,
        .target = target,
        .optimize = optimize,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .release_use_closure = false, // causing errors with miniaudio? might need to add a custom exerns file for closure
        .use_emmalloc = true,
        .use_filesystem = true,
        .shell_file_path = dep_sokol.path("src/sokol/web/shell.html").getPath(b),
        .extra_args = &.{
            "-sUSE_OFFSET_CONVERTER=1",
            "-sTOTAL_STACK=16MB",
            "--preload-file=assets/",
            "-sALLOW_MEMORY_GROWTH=1",
            "-sSAFE_HEAP=0",
            "-sERROR_ON_UNDEFINED_SYMBOLS=0",
        },
    });
}

pub fn getEmsdkSystemIncludePath(dep_sokol: *Build.Dependency) Build.LazyPath {
    const dep_emsdk = dep_sokol.builder.dependency("emsdk", .{});
    return dep_emsdk.path("upstream/emscripten/cache/sysroot/include");
}

pub fn emscriptenRunStep(b: *Build, name: []const u8, dep_sokol: *Build.Dependency) *Build.Step.Run {
    const emsdk = dep_sokol.builder.dependency("emsdk", .{});
    return sokol.emRunStep(b, .{ .name = name, .emsdk = emsdk });
}
// Adds a run step to compile shaders, expects the shader compiler in ../sokol-tools-bin/
fn buildShaders(b: *Build) void {
    const sokol_tools_bin_dir = "../sokol-tools-bin/bin/";
    const shaders_dir = "assets/shaders/";
    const shaders_out_dir = "src/framework/graphics/shaders/";

    const shaders = .{
        "basic-lighting",
        "default",
        "default-mesh",
        "emissive",
        "skinned-basic-lighting",
        "skinned",
    };

    const optional_shdc: ?[:0]const u8 = comptime switch (builtin.os.tag) {
        .windows => "win32/sokol-shdc.exe",
        .linux => "linux/sokol-shdc",
        .macos => if (builtin.cpu.arch.isX86()) "osx/sokol-shdc" else "osx_arm64/sokol-shdc",
        else => null,
    };

    if (optional_shdc == null) {
        std.log.warn("unsupported host platform, skipping shader compiler step", .{});
        return;
    }

    const shdc_step = b.step("shaders", "Compile shaders (needs ../sokol-tools-bin)");
    const shdc_path = sokol_tools_bin_dir ++ optional_shdc.?;
    const slang = "glsl300es:glsl430:wgsl:metal_macos:metal_ios:metal_sim:hlsl4";

    // build the .zig versions
    inline for (shaders) |shader| {
        const shader_with_ext = shader ++ ".glsl";
        const cmd = b.addSystemCommand(&.{
            shdc_path,
            "-i",
            shaders_dir ++ shader_with_ext,
            "-o",
            shaders_out_dir ++ shader_with_ext ++ ".zig",
            "-l",
            slang,
            "-f",
            "sokol_zig",
            "--reflection",
        });
        shdc_step.dependOn(&cmd.step);
    }

    // build the yaml reflection versions
    inline for (shaders) |shader| {
        const shader_with_ext = shader ++ ".glsl";
        fs.cwd().makePath(shaders_dir ++ "built/" ++ shader) catch |err| {
            log.info("Could not create path {}", .{err});
        };

        const cmd = b.addSystemCommand(&.{
            shdc_path,
            "-i",
            shaders_dir ++ shader_with_ext,
            "-o",
            shaders_dir ++ "built/" ++ shader ++ "/" ++ shader,
            "-l",
            slang,
            "-f",
            "bare_yaml",
            "--reflection",
        });
        shdc_step.dependOn(&cmd.step);
    }
}
