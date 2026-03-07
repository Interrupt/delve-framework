const std = @import("std");
const fmt = @import("fmt");
const debug = @import("../debug.zig");
const binder = @import("binder.zig");
const lua_util = @import("lua.zig");
const math = @import("../math.zig");
const modules = @import("../modules.zig");
const app = @import("../platform/app.zig");
const zlua = @import("zlua");

pub const BoundType = binder.BoundType;
const Lua = zlua.Lua;

const functions_to_ignore = [_][:0]const u8{ "libInit", "libTick", "libDraw", "libCleanup" };

pub const ScriptFn = struct {
    name: [*:0]const u8,
    luaFn: zlua.FnReg,
};

pub fn init() !void {
    // Start lua
    try lua_util.init();

    // Make a Lua type registry with some basic types
    const bound_types = &[_]binder.BoundType{
        .{ .Type = math.Vec2, .name = "delve.math.Vec2", .ignore_fields = &[_][:0]const u8{} },
        .{ .Type = math.Vec3, .name = "delve.math.Vec3", .ignore_fields = &[_][:0]const u8{} },
        .{ .Type = math.Vec4, .name = "delve.math.Vec4", .ignore_fields = &[_][:0]const u8{} },
        .{ .Type = math.Mat4, .name = "delve.math.Mat4", .ignore_fields = &[_][:0]const u8{} },
        .{ .Type = math.Quaternion, .name = "delve.math.Quaternion", .ignore_fields = &[_][:0]const u8{} },
        .{ .Type = app, .name = "delve.platform.App", .ignore_fields = &[_][:0]const u8{} },
    };

    const registry = binder.Registry(bound_types);
    try registry.bindTypes(lua_util.getLua());

    // Bind all the libraries using some meta programming magic at compile time
    try bindZigLibrary("assets", @import("../api/assets.zig"), registry);
    try bindZigLibrary("display", @import("../api/display.zig"), registry);
    try bindZigLibrary("draw", @import("../api/draw.zig"), registry);
    try bindZigLibrary("text", @import("../api/text.zig"), registry);
    try bindZigLibrary("graphics", @import("../api/graphics.zig"), registry);
    try bindZigLibrary("input.mouse", @import("../api/mouse.zig"), registry);
    try bindZigLibrary("input.keyboard", @import("../api/keyboard.zig"), registry);
}

pub fn deinit() void {
    lua_util.deinit();
}

fn bindZigLibrary(comptime name: [:0]const u8, comptime zigfile: anytype, comptime registry: anytype) !void {
    const found_fns = comptime registry.findLibraryFunctions(zigfile, &functions_to_ignore);
    registry.bindLibrary(lua_util.getLua(), name, found_fns);

    // Register the library as a module to tie into the app lifecycle
    var scriptApiModule = modules.Module{
        .name = "scriptapi." ++ name,
        .priority = modules.Priority.first, // initialize these right away
    };

    // bind lifecycle functions for the library module
    if (@hasDecl(zigfile, "libInit")) {
        scriptApiModule.init_fn = zigfile.libInit;
    }
    if (@hasDecl(zigfile, "libTick")) {
        scriptApiModule.tick_fn = zigfile.libTick;
    }
    if (@hasDecl(zigfile, "libDraw")) {
        scriptApiModule.draw_fn = zigfile.libDraw;
    }
    if (@hasDecl(zigfile, "libPreDraw")) {
        scriptApiModule.pre_draw_fn = zigfile.libPreDraw;
    }
    if (@hasDecl(zigfile, "libPostDraw")) {
        scriptApiModule.post_draw_fn = zigfile.libPostDraw;
    }
    if (@hasDecl(zigfile, "libCleanup")) {
        scriptApiModule.cleanup_fn = zigfile.libCleanup;
    }

    try modules.registerModule(scriptApiModule);
}
