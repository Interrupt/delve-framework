const std = @import("std");
const fmt = @import("fmt");
const ziglua = @import("ziglua");
const debug = @import("../debug.zig");

const Lua = ziglua.Lua;

pub fn makeLuaBinding(name: [:0]const u8, comptime function: anytype) ziglua.FnReg {
    return ziglua.FnReg { .name = name, .func = ziglua.wrap(bindFuncLua(function)) };
}

fn bindFuncLua(comptime function: anytype) fn(lua: *Lua) i32{
    return (opaque {
        pub fn lua_call(lua: *Lua) i32 {
            // Get a tuple of the various types of the arguments, and then create one
            const ArgsTuple = std.meta.ArgsTuple(@TypeOf(function));
            var args: ArgsTuple = undefined;

            const params = @typeInfo(@TypeOf(function)).Fn.params;

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
                        @compileError("Unimplemented LUA argument type!");
                    }
                }
            }

            @call(.auto, function, args);
            return 0;
        }
    }).lua_call;
}
