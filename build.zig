const std = @import("std");
const Build = std.Build;
const ziglua = @import("ziglua");
const sokol = @import("sokol");
const system_sdk = @import("system-sdk");

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
    });

    const ziglua_dep = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    });

    const zmesh = b.dependency("zmesh", .{
        .target = target,
        .optimize = optimize,
    });

    const zaudio = b.dependency("zaudio", .{
        .target = target,
        .optimize = optimize,
    });

    const zstbi = b.dependency("zstbi", .{
        .target = target,
        .optimize = optimize,
    });

    const sokol_item = .{ .module = dep_sokol.module("sokol"), .name = "sokol" };
    const ziglua_item = .{ .module = ziglua_dep.module("ziglua"), .name = "ziglua" };
    const zmesh_item = .{ .module = zmesh.module("root"), .name = "zmesh" };
    const zstbi_item = .{ .module = zstbi.module("root"), .name = "zstbi" };
    const zaudio_item = .{ .module = zaudio.module("root"), .name = "zaudio" };

    const delve_module_imports = [_]ModuleImport{
        sokol_item,
        zmesh_item,
        zstbi_item,
        zaudio_item,
        // ziglua_item,
    };

    const link_libraries = [_]*Build.Step.Compile{
        zmesh.artifact("zmesh"),
        zstbi.artifact("zstbi"),
        zaudio.artifact("miniaudio"),
        // ziglua_dep.artifact("lua"),
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

    for (build_collection.add_imports) |build_import| {
        delve_mod.addImport(build_import.name, build_import.module);
    }

    if (!target.result.isWasm()) {
        // Ziglua isn't building under Emscripten yet!
        delve_mod.addImport(ziglua_item.name, ziglua_item.module);
    }

    for (build_collection.link_libraries) |lib| {
        delve_mod.linkLibrary(lib);
    }

    // If we have a defined sysroot, eg for emscpriten, use that include path too
    if (b.sysroot) |sysroot| {
        const include_path = try std.fs.path.join(b.allocator, &.{ sysroot, "include" });
        defer b.allocator.free(include_path);
        delve_mod.addIncludePath(b.path(include_path));

        for (build_collection.link_libraries) |lib| {
            lib.addIncludePath(b.path(include_path));
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
        "forest",
        "framepacing",
        "frustums",
        "lua",
        "meshbuilder",
        "meshes",
        "passes",
        "quakemap",
        "rays",
        "stresstest",
    };

    for (examples) |example_item| {
        try buildExample(b, example_item, delve_mod, delve_lib);
    }

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

        const include_path = try std.fs.path.join(b.allocator, &.{ b.sysroot.?, "include" });
        defer b.allocator.free(include_path);
        app.addIncludePath(b.path(include_path));
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

    return try sokol.emLinkStep(b, .{
        .lib_main = app,
        .target = target,
        .optimize = optimize,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .use_emmalloc = true,
        .use_filesystem = true,
        .shell_file_path = dep_sokol.path("src/sokol/web/shell.html").getPath(b),
        .extra_args = &.{
            "-sUSE_OFFSET_CONVERTER=1",
            "-sTOTAL_STACK=16MB",
            "--preload-file=assets/",
            "-sALLOW_MEMORY_GROWTH=1",
            "-sSAFE_HEAP=0",
        },
    });
}

pub fn emscriptenRunStep(b: *Build, name: []const u8, dep_sokol: *Build.Dependency) *Build.Step.Run {
    const emsdk = dep_sokol.builder.dependency("emsdk", .{});
    return sokol.emRunStep(b, .{ .name = name, .emsdk = emsdk });
}
