const std = @import("std");
const fmt = @import("fmt");
const ziglua = @import("ziglua");
const debug = @import("../debug.zig");
const lua_util = @import("lua.zig");

const Lua = ziglua.Lua;

pub const ScriptFn = struct {
    name: [*:0]const u8,
    luaFn: ziglua.FnReg,
};

pub fn init() void {
    // Bind all the libraries using some meta programming magic at compile time
    const display_module_fns = comptime findLibraryFunctions(@import("../api/display.zig"));
    bindLibrary("display", display_module_fns);

    const draw_module_fns = comptime findLibraryFunctions(@import("../api/draw.zig"));
    bindLibrary("draw", draw_module_fns);

    const mouse_module_fns = comptime findLibraryFunctions(@import("../api/mouse.zig"));
    bindLibrary("input.mouse", mouse_module_fns);
}

pub fn deinit() void {

}

fn isModuleFunction(comptime in_type: anytype) bool {
    return @typeInfo(in_type) == .Fn;
}

fn findLibraryFunctions(comptime module: anytype) []const ScriptFn {
    comptime {
        // Get all the public declarations in this module
        const decls = @typeInfo(module).Struct.decls;

        // filter out only the public functions
        var gen_fields: []const std.builtin.Type.Declaration = &[_]std.builtin.Type.Declaration {};
        for (decls) |d| {
            const field = @field(module, d.name);
            if(isModuleFunction(@TypeOf(field))) {
                gen_fields = gen_fields ++ .{ d };
            }
        }

        var found: []const ScriptFn = &[_]ScriptFn{};
        for (gen_fields) |d| {
            // convert the name string to be :0 terminated
            var field_name: [:0]const u8 = d.name ++ "";

            found = found ++ .{ wrapFn(field_name, @field(module, d.name)) };
        }
        return found;
    }
}

fn wrapFn(name: [:0]const u8, comptime func: anytype) ScriptFn {
    return ScriptFn {
        .name = name,
        .luaFn = makeLuaBinding(name, func),
    };
}

fn bindLibrary(comptime name: [:0]const u8, comptime funcs: []const ScriptFn) void {
    // Bind these functions with Lua!
    lua_util.openModule(name, makeLuaOpenLibFn(funcs));
}

fn makeLuaOpenLibFn(comptime funcs: []const ScriptFn) fn(*Lua) i32 {
    return opaque {
        pub fn inner(lua: *Lua) i32 {
            var lib_funcs: [funcs.len]ziglua.FnReg = undefined;

            inline for(funcs, 0..) |f, i| {
                lib_funcs[i] = f.luaFn;
            }

            lua.newLib(&lib_funcs);
            return 1;
        }
    }.inner;
}

fn makeLuaBinding(name: [:0]const u8, comptime function: anytype) ziglua.FnReg {
    return ziglua.FnReg { .name = name, .func = ziglua.wrap(bindFuncLua(function)) };
}

fn bindFuncLua(comptime function: anytype) fn(lua: *Lua) i32{
    return (opaque {
        pub fn lua_call(lua: *Lua) i32 {
            // Get a tuple of the various types of the arguments, and then create one
            const ArgsTuple = std.meta.ArgsTuple(@TypeOf(function));
            var args: ArgsTuple = undefined;

            const fn_info = @typeInfo(@TypeOf(function)).Fn;
            const params = fn_info.params;

            inline for (params, 0..) |param, i| {
                const param_type = param.type.?;
                const lua_idx = i + 1;

                switch(param_type) {
                    c_int, i8, i16, i32, i64, u8, u16, u32, u64 => {
                        // ints
                        args[i] = @intFromFloat(lua.toNumber(lua_idx) catch 0);
                    },
                    f16, f32, f64 => {
                        // floats
                        args[i] = @floatCast(lua.toNumber(lua_idx) catch 0);
                    },
                    [*:0]const u8 => {
                        // strings
                        args[i] = lua.toString(lua_idx) catch "";
                    },
                    else => {
                        @compileError("Unimplemented LUA argument type: " ++ @typeName(param_type));
                    }
                }
            }

            if(fn_info.return_type == null) {
                @compileError("Function has no return type?! This should not be possible.");
            }

            const ret_val = @call(.auto, function, args);
            switch(@TypeOf(ret_val)) {
                void => {
                    return 0;
                },
                bool => {
                    lua.pushBoolean(ret_val);
                    return 1;
                },
                std.meta.Tuple(&.{f32, f32}) => {
                    lua.pushNumber(ret_val[0]);
                    lua.pushNumber(ret_val[1]);
                    return 2;
                },
                else => {
                    @compileError("Unimplemented LUA return type: " ++ @typeName(@TypeOf(ret_val)));
                }
            }

            @compileError("LUA did not return number of return values correctly!");
        }
    }).lua_call;
}
