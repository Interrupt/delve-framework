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

    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    const zmesh = b.dependency("zmesh", .{});
    const zaudio = b.dependency("zaudio", .{});

    const sokol_item = .{ .module = dep_sokol.module("sokol"), .name = "sokol" };
    const ziglua_item = .{ .module = ziglua_mod, .name = "ziglua" };
    _ = ziglua_item;
    const zmesh_item = .{ .module = zmesh.module("root"), .name = "zmesh" };
    const zstbi_item = .{ .module = zstbi_pkg.zstbi, .name = "zstbi" };
    const zaudio_item = .{ .module = zaudio.module("root"), .name = "zaudio" };
    _ = zaudio_item;

    const delve_module_imports = [_]ModuleImport{
        sokol_item,
        // ziglua_item,
        zmesh_item,
        zstbi_item,
        // zaudio_item,
    };

    const link_libraries = [_]*Build.Step.Compile{
        zmesh.artifact("zmesh"),
        zstbi_pkg.zstbi_c_cpp,
        // zaudio.artifact("miniaudio"),
    };

    const build_collection: BuildCollection = .{
        .add_imports = &delve_module_imports,
        .link_libraries = &link_libraries,
    };

    // Delve module
    const delve_mod = b.addModule("delve", .{
        .root_source_file = .{ .path = "src/framework/delve.zig" },
        .target = target,
        .optimize = optimize,
    });

    const include_path = try std.fs.path.join(b.allocator, &.{ b.sysroot.?, "include" });
    defer b.allocator.free(include_path);
    delve_mod.addIncludePath(.{ .path = include_path });

    for (build_collection.add_imports) |build_import| {
        delve_mod.addImport(build_import.name, build_import.module);
    }
    for (build_collection.link_libraries) |lib| {
        lib.addIncludePath(.{ .path = include_path });
        delve_mod.linkLibrary(lib);
    }

    // Delve Static Library artifact
    const delve_lib = b.addStaticLibrary(.{
        .target = target,
        .optimize = optimize,
        .name = "delve",
        .root_source_file = .{ .path = "src/framework/delve.zig" },
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
        .root_source_file = .{ .path = "src/framework/delve.zig" },
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
            .root_source_file = .{ .path = root_source_file },
        });

        const include_path = try std.fs.path.join(b.allocator, &.{ b.sysroot.?, "include" });
        defer b.allocator.free(include_path);
        app.addIncludePath(.{ .path = include_path });
    } else {
        app = b.addExecutable(.{
            .target = target,
            .optimize = optimize,
            .name = name,
            .root_source_file = .{ .path = root_source_file },
        });
    }

    // app.linkLibC();

    // app.linkLibCpp();
    // app.addSystemIncludePath(.{ .path = "/Library/Developer/CommandLineTools/usr/include/c++/v1" });
    // app.addIncludePath(.{ .path = "/Library/Developer/CommandLineTools/usr/include/c++/v1" });
    // app.addIncludePath("/usr/include");

    app.root_module.addImport("delve", delve_module);
    app.linkLibrary(delve_lib);

    if (target.result.isWasm()) {
        // TODO: Still sorting out WASM builds
        //
        // create a build step which invokes the Emscripten linker

        const dep_sokol = b.dependency("sokol", .{
            .target = target,
            .optimize = optimize,
        });

        const emsdk = dep_sokol.builder.dependency("emsdk", .{});
        const link_step = try sokol.emLinkStep(b, .{
            .lib_main = app,
            .target = target,
            .optimize = optimize,
            .emsdk = emsdk,
            .use_webgl2 = true,
            .use_emmalloc = true,
            .use_filesystem = false,
            .shell_file_path = dep_sokol.path("src/sokol/web/shell.html").getPath(b),
            .extra_args = &.{"-sUSE_OFFSET_CONVERTER=1"},
        });

        // // ...and a special run step to start the web build output via 'emrun'
        const run = sokol.emRunStep(b, .{ .name = example, .emsdk = emsdk });
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
