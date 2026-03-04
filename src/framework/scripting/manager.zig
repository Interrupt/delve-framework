const std = @import("std");
const fmt = @import("fmt");
const debug = @import("../debug.zig");
const binder = @import("binder.zig");
const lua_util = @import("lua.zig");
const modules = @import("../modules.zig");
const zlua = @import("zlua");

pub const BoundType = binder.BoundType;
const Lua = zlua.Lua;

const functions_to_ignore = [_][:0]const u8{ "libInit", "libTick", "libDraw", "libCleanup" };

pub const ScriptFn = struct {
    name: [*:0]const u8,
    luaFn: zlua.FnReg,
};

pub fn init(comptime boundTypes: []const binder.BoundType) !void {
    // Start lua
    try lua_util.init();

    const registry = binder.Registry(boundTypes);

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

// fn isModuleFunction(comptime name: [:0]const u8, comptime in_type: anytype) bool {
//     // Don't try to bind the script lib lifecycle functions!
//     if (std.mem.eql(u8, name, "libInit") or std.mem.eql(u8, name, "libTick") or std.mem.eql(u8, name, "libDraw") or std.mem.eql(u8, name, "libCleanup"))
//         return false;
//
//     // Hide some other functions that start with '_'
//     if (name[0] == '_')
//         return false;
//
//     return @typeInfo(in_type) == .@"fn";
// }

// fn findLibraryFunctions(comptime module: anytype) []const ScriptFn {
//     comptime {
//         // Get all the public declarations in this module
//         const decls = @typeInfo(module).@"struct".decls;
//         // filter out only the public functions
//         var gen_fields: []const std.builtin.Type.Declaration = &[_]std.builtin.Type.Declaration{};
//         for (decls) |d| {
//             const field = @field(module, d.name);
//             if (isModuleFunction(d.name ++ "", @TypeOf(field))) {
//                 gen_fields = gen_fields ++ .{d};
//             }
//         }
//
//         var found: []const ScriptFn = &[_]ScriptFn{};
//         for (gen_fields) |d| {
//             // convert the name string to be :0 terminated
//             const field_name: [:0]const u8 = d.name ++ "";
//
//             found = found ++ .{wrapFn(field_name, @field(module, d.name))};
//         }
//         return found;
//     }
// }

// fn wrapFn(name: [:0]const u8, comptime func: anytype) ScriptFn {
//     return ScriptFn{
//         .name = name,
//         .luaFn = makeLuaBinding(name, func),
//     };
// }

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

// fn bindLibrary(comptime name: [:0]const u8, comptime funcs: []const ScriptFn) void {
//     // Bind these functions with Lua!
//     lua_util.openModule(name, makeLuaOpenLibFn(funcs));
// }
//
// fn makeLuaOpenLibFn(comptime funcs: []const ScriptFn) fn (*Lua) i32 {
//     return opaque {
//         pub fn inner(lua: *Lua) i32 {
//             var lib_funcs: [funcs.len]zlua.FnReg = undefined;
//
//             inline for (funcs, 0..) |f, i| {
//                 lib_funcs[i] = f.luaFn;
//             }
//
//             lua.newLib(&lib_funcs);
//             return 1;
//         }
//     }.inner;
// }

// fn makeLuaBinding(name: [:0]const u8, comptime function: anytype) zlua.FnReg {
//     return zlua.FnReg{ .name = name, .func = zlua.wrap(bindFuncLua(function)) };
// }

// fn bindFuncLua(comptime function: anytype) fn (lua: *Lua) i32 {
//     return (opaque {
//         pub fn lua_call(lua: *Lua) i32 {
//             // Get a tuple of the various types of the arguments, and then create one
//             const ArgsTuple = std.meta.ArgsTuple(@TypeOf(function));
//             var args: ArgsTuple = undefined;
//
//             const fn_info = @typeInfo(@TypeOf(function)).@"fn";
//             const params = fn_info.params;
//
//             inline for (params, 0..) |param, i| {
//                 const param_type = param.type.?;
//                 const lua_idx = i + 1;
//
//                 switch (param_type) {
//                     bool => {
//                         args[i] = lua.toBool(lua_idx) catch false;
//                     },
//                     c_int, usize, i8, i16, i32, i64, u8, u16, u32, u64 => {
//                         // ints
//                         args[i] = std.math.lossyCast(param_type, lua.toNumber(lua_idx) catch 0);
//                     },
//                     f16, f32, f64 => {
//                         // floats
//                         args[i] = std.math.lossyCast(param_type, lua.toNumber(lua_idx) catch 0);
//                     },
//                     [*:0]const u8 => {
//                         // strings
//                         args[i] = lua.toString(lua_idx) catch "";
//                     },
//                     else => {
//                         @compileError("Unimplemented LUA argument type: " ++ @typeName(param_type));
//                     },
//                 }
//             }
//
//             if (fn_info.return_type == null) {
//                 @compileError("Function has no return type?! This should not be possible.");
//             }
//
//             const ret_val = @call(.auto, function, args);
//             switch (@TypeOf(ret_val)) {
//                 void => {
//                     return 0;
//                 },
//                 bool => {
//                     lua.pushBoolean(ret_val);
//                     return 1;
//                 },
//                 c_int, usize, i8, i16, i32, i64, u8, u16, u32, u64 => {
//                     lua.pushNumber(@floatFromInt(ret_val));
//                     return 1;
//                 },
//                 f16, f32, f64 => {
//                     lua.pushNumber(ret_val);
//                     return 1;
//                 },
//                 [*:0]const u8 => {
//                     lua.pushString(ret_val);
//                     return 1;
//                 },
//                 std.meta.Tuple(&.{ f32, f32 }) => {
//                     // probably is a way to handle any tuple types
//                     lua.pushNumber(ret_val[0]);
//                     lua.pushNumber(ret_val[1]);
//                     return 2;
//                 },
//                 else => {
//                     @compileError("Unimplemented LUA return type: " ++ @typeName(@TypeOf(ret_val)));
//                 },
//             }
//
//             @compileError("LUA did not return number of return values correctly!");
//         }
//     }).lua_call;
// }
