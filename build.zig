const std = @import("std");
const Build = std.Build;
const sokol = @import("sokol");
const ziglua = @import("ziglua");
const zstbi = @import("zstbi");
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

    const ziglua_mod = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    }).module("ziglua");

    // const zmesh_pkg = zmesh.package(b, target, optimize, .{});
    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    // const zaudio_pkg = zaudio.package(b, target, optimize, .{});

    const zmesh = b.dependency("zmesh", .{});
    const zaudio = b.dependency("zaudio", .{});

    const sokol_item = .{ .module = dep_sokol.module("sokol"), .name = "sokol" };
    const ziglua_item = .{ .module = ziglua_mod, .name = "ziglua" };
    const zmesh_item = .{ .module = zmesh.module("root"), .name = "zmesh" };
    // const zmesh_options_item = .{ .module = zmesh_pkg.zmesh_options, .name = "zmesh_options" };
    const zstbi_item = .{ .module = zstbi_pkg.zstbi, .name = "zstbi" };
    const zaudio_item = .{ .module = zaudio.module("root"), .name = "zaudio" };
    const delve_module_imports = [_]ModuleImport{
        sokol_item,
        ziglua_item,
        zmesh_item,
        // zmesh_options_item,
        zstbi_item,
        zaudio_item,
    };
    const link_libraries = [_]*Build.Step.Compile{
        // zmesh_pkg.zmesh_c_cpp,
        zmesh.artifact("zmesh"),
        zstbi_pkg.zstbi_c_cpp,
        zaudio.artifact("miniaudio"),
        // zaudio_pkg.zaudio_c_cpp,
    };

    var build_collection: BuildCollection = .{
        .add_imports = &delve_module_imports,
        .link_libraries = &link_libraries,
    };

    // Delve module
    const delve_mod = b.addModule("delve", .{
        .root_source_file = .{ .path = "src/framework/delve.zig" },
        .target = target,
        .optimize = optimize,
    });

    for (build_collection.add_imports) |build_import| {
        delve_mod.addImport(build_import.name, build_import.module);
    }
    for (build_collection.link_libraries) |lib| {
        delve_mod.linkLibrary(lib);
    }

    // create new list with delve included
    const app_module_imports = [_]ModuleImport{
        sokol_item,
        ziglua_item,
        zmesh_item,
        // zmesh_options_item,
        zstbi_item,
        zaudio_item,
        .{ .module = delve_mod, .name = "delve" },
    };
    build_collection.add_imports = &app_module_imports;

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
        "stresstest",
    };

    inline for (examples) |example_item| {
        try buildExample(b, example_item, build_collection);
    }

    // TESTS
    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/framework/delve.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

fn buildExample(b: *std.Build, comptime example: []const u8, build_collection: BuildCollection) !void {
    const name: []const u8 = example;
    const root_source_file: []const u8 = "src/examples/" ++ example ++ ".zig";

    var app: *Build.Step.Compile = undefined;
    // special case handling for native vs web build
    if (target.result.isWasm()) {
        app = b.addStaticLibrary(.{
            .target = target,
            .optimize = optimize,
            .name = name,
            .root_source_file = .{ .path = root_source_file },
        });
    } else {
        app = b.addExecutable(.{
            .target = target,
            .optimize = optimize,
            .name = name,
            .root_source_file = .{ .path = root_source_file },
        });
    }

    for (build_collection.add_imports) |build_import| {
        app.root_module.addImport(build_import.name, build_import.module);
    }
    for (build_collection.link_libraries) |lib| {
        app.linkLibrary(lib);
    }

    if (target.result.isWasm()) {
        // create a build step which invokes the Emscripten linker
        // const emsdk = dep_sokol.builder.dependency("emsdk", .{});
        // const link_step = try sokol.emLinkStep(b, .{
        //     .lib_main = app,
        //     .target = target,
        //     .optimize = optimize,
        //     .emsdk = emsdk,
        //     .use_webgl2 = true,
        //     .use_emmalloc = true,
        //     .use_filesystem = false,
        //     .shell_file_path = dep_sokol.path("3rdparty/sokol-zig/web/shell.html").getPath(b),
        // });
        // // ...and a special run step to start the web build output via 'emrun'
        // const run = sokol.emRunStep(b, .{ .name = example[0], .emsdk = emsdk });
        // run.step.dependOn(&link_step.step);

        // var option_buffer = [_]u8{undefined} ** 100;
        // const run_name = try std.fmt.bufPrint(&option_buffer, "run-{s}", .{name});
        // var description_buffer = [_]u8{undefined} ** 200;
        // const descr_name = try std.fmt.bufPrint(&description_buffer, "run {s}", .{name});
        // b.step(run_name, descr_name).dependOn(&run.step);
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
