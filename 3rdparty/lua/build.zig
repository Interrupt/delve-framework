const std = @import("std");
// const emscripten = @import("emscripten");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("lua54", .{});

    const is_emscripten = target.result.os.tag == .emscripten;

    const lua = b.addModule("lua", .{
        .root_source_file = b.path("src/lua.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .name = "luac",
        .root_module = lua,
        .version = std.SemanticVersion{ .major = 5, .minor = 4, .patch = 8 },
    });

    lib.addIncludePath(upstream.path("src"));

    if (is_emscripten) {
        const activate_emsdk_step = @import("zemscripten").activateEmsdkStep(b);

        const zemscripten = b.dependency("zemscripten", .{});
        lib.root_module.addImport("zemscripten", zemscripten.module("root"));

        const lua_source_paths = b.path("src");

        // const emscripten_cache_path = emscripten.getEmscriptenCachePath(b);
        // lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ emscripten_cache_path, "sysroot", "include" }) });

        // const flags = [_][]const u8{
        //     "-std=gnu99",
        //     "-DLUA_USE_POSIX",
        //     if (optimize == .Debug) "-DLUA_USE_APICHECK" else "",
        //     "-I",
        //     upstream.path("src").getPath(b),
        // };

        var emcc_flags = @import("zemscripten").emccDefaultFlags(b.allocator, .{
            .optimize = optimize,
            .fsanitize = false,
        });
        emcc_flags.put("-std=gnu99", {}) catch {};
        emcc_flags.put("-DLUA_USE_POSIX", {}) catch {};

        var emcc_settings = @import("zemscripten").emccDefaultSettings(b.allocator, .{
            .optimize = optimize,
            .emsdk_allocator = .emmalloc,
        });
        emcc_settings.put("ALLOW_MEMORY_GROWTH", "1") catch {};

        const emcc_step = @import("zemscripten").emccStep(
            b,
            &.{lua_source_paths}, // src file paths
            &.{lib}, // src compile steps
            .{
                .optimize = optimize,
                .flags = emcc_flags,
                .settings = emcc_settings,
                .use_preload_plugins = true,
                .embed_paths = &.{},
                .preload_paths = &.{},
                .shell_file_path = null, // set this to override the default html shell
                .js_library_path = null,
                .out_file_name = "wasm.lua",
                .install_dir = .{ .custom = "web" },
            },
        );

        emcc_step.dependOn(activate_emsdk_step);
        b.getInstallStep().dependOn(emcc_step);
        b.installArtifact(lib);
    } else {
        const flags = [_][]const u8{
            "-std=gnu99",
            "-DLUA_USE_POSIX",
            if (optimize == .Debug) "-DLUA_USE_APICHECK" else "",
        };

        lib.addCSourceFiles(.{
            .root = upstream.path("src"),
            .files = &lua_source_files,
            .flags = &flags,
        });
        lib.linkLibC();
    }

    lib.installHeader(upstream.path("src/lua.h"), "lua.h");
    lib.installHeader(upstream.path("src/luaconf.h"), "luaconf.h");
    lib.installHeader(upstream.path("src/lualib.h"), "lualib.h");
    lib.installHeader(upstream.path("src/lauxlib.h"), "lauxlib.h");

    b.installArtifact(lib);
}

const lua_source_files = [_][]const u8{
    "lapi.c",
    "lcode.c",
    "ldebug.c",
    "ldo.c",
    "ldump.c",
    "lfunc.c",
    "lgc.c",
    "llex.c",
    "lmem.c",
    "lobject.c",
    "lopcodes.c",
    "lparser.c",
    "lstate.c",
    "lstring.c",
    "ltable.c",
    "ltm.c",
    "lundump.c",
    "lvm.c",
    "lzio.c",
    "lauxlib.c",
    "lbaselib.c",
    "ldblib.c",
    "liolib.c",
    "lmathlib.c",
    "loslib.c",
    "ltablib.c",
    "lstrlib.c",
    "loadlib.c",
    "linit.c",
    "lctype.c",
    "lcorolib.c",
    "lutf8lib.c",
};
