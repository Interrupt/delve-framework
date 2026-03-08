const std = @import("std");
const debug = @import("../debug.zig");

const zlua = @import("zlua");
const Lua = zlua.Lua;

pub const BoundType = struct {
    Type: type,
    name: [:0]const u8,
    ignore_fields: []const [:0]const u8,
};

pub fn Registry(comptime entries: []const BoundType) type {
    return struct {
        pub const registry = entries;

        pub fn getMetaTableName(comptime T: type) [:0]const u8 {
            inline for (registry) |entry| {
                if (entry.Type == T) return entry.name;
            }
            debug.warning("Type not found in Lua registry! " ++ @typeName(T), .{});
            return "_notFound";
        }

        pub fn isRegistered(comptime T: type) bool {
            inline for (registry) |entry| {
                if (entry.Type == T) return true;
            }
            return false;
        }

        pub fn hasDestroyFunc(comptime T: type) bool {
            return std.meta.hasFn(T, "destroy");
        }

        pub fn hasIndexFunc(comptime T: type) bool {
            return std.meta.hasFn(T, "__index");
        }

        pub fn hasNewIndexFunc(comptime T: type) bool {
            return std.meta.hasFn(T, "__newindex");
        }

        pub fn bindTypes(luaState: *zlua.Lua) !void {
            inline for (registry) |entry| {
                try bindType(luaState, entry);
            }
        }

        // __index is called when Lua gets a value from a table
        pub fn indexLookupFunc(comptime T: type, luaState: *Lua, meta_table_name: [:0]const u8) i32 {
            // Get our key
            const key = luaState.toString(-1) catch |err| {
                debug.fatal("Lua: indexLookupFunc could not get key! {s}: {any}", .{ meta_table_name, err });
                return 0;
            };

            // If this is a userdata object, check if it has this property
            if (luaState.isUserdata(1)) {
                const ptr = luaState.checkUserdata(T, 1, meta_table_name);

                // Grab this field if we find it
                inline for (std.meta.fields(T)) |field| {
                    if (std.mem.eql(u8, key, field.name)) {
                        const val = @field(ptr, field.name);
                        return pushAny(luaState, val);
                    }
                }
            }

            // fallback to our own metatable so that we can still call bound functions like self:ourFunc()

            // get our own metatable
            luaState.getMetatable(1) catch {
                debug.log("LuaComponent __index could not get metatable!", .{});
                return 0;
            };

            // push the key again
            luaState.pushValue(2);

            // return metatable[key]
            _ = luaState.getTable(-2);

            return 1;
        }

        // __newindex is called when Lua sets a value on a table
        pub fn indexSetValueFunc(comptime T: type, luaState: *Lua, meta_table_name: [:0]const u8) i32 {
            // Get our key
            const key = luaState.toString(-2) catch |err| {
                debug.fatal("Lua: indexLookupFunc could not get key! {s}: {any}", .{ meta_table_name, err });
                return 0;
            };

            // If this is a userdata object, check if it has this property
            if (luaState.isUserdata(1)) {
                const ptr = luaState.checkUserdata(T, 1, meta_table_name);

                // Set this field if we find it
                inline for (std.meta.fields(T)) |field| {
                    if (std.mem.eql(u8, key, field.name)) {
                        const val = toAny(luaState, field.type, -1) catch {
                            luaState.raiseErrorStr("Could not set field! Should be type %s", .{@typeName(field.type)});
                            return 0;
                        };

                        @field(ptr, field.name) = val;
                        return 1;
                    }
                }
            }

            debug.warning("Lua: {s}: Could not find field '{s}' to set", .{ meta_table_name, key });
            return 0;
        }

        pub fn bindType(luaState: *zlua.Lua, comptime bound_type: BoundType) !void {
            const T = bound_type.Type;
            const meta_table_name = bound_type.name;

            const startTop = luaState.getTop();

            // Make our new userData and metaTable
            _ = luaState.newUserdata(T, @sizeOf(T));
            _ = try luaState.newMetatable(meta_table_name);

            // GC func is required for memory management
            // Wire GC up to our destroy function if found!
            if (comptime hasDestroyFunc(T)) {
                // Make our GC function to wire to _gc in lua
                const gcFunc = struct {
                    fn inner(L: *zlua.Lua) i32 {
                        const ptr = L.checkUserdata(T, 1, meta_table_name);
                        ptr.destroy();
                        return 0;
                    }
                }.inner;

                luaState.pushClosure(zlua.wrap(gcFunc), 0);
                luaState.setField(-2, "__gc");
            }

            if (comptime hasIndexFunc(T)) {
                // Wire to __index in lua
                const indexFunc = struct {
                    fn inner(L: *zlua.Lua) i32 {
                        const ptr = L.checkUserdata(T, 1, meta_table_name);
                        return ptr.__index(L);
                    }
                }.inner;

                luaState.pushClosure(zlua.wrap(indexFunc), 0);
                luaState.setField(-2, "__index");
            } else {
                // If no index func was given, use our own that indexes to ourself
                const indexFunc = struct {
                    fn inner(L: *zlua.Lua) i32 {
                        return indexLookupFunc(T, L, meta_table_name);
                    }
                }.inner;

                luaState.pushClosure(zlua.wrap(indexFunc), 0);
                luaState.setField(-2, "__index");
            }

            if (comptime hasNewIndexFunc(T)) {
                // Wire to __newindex in lua
                const newIndexFunc = struct {
                    fn inner(L: *zlua.Lua) i32 {
                        const ptr = L.checkUserdata(T, 1, meta_table_name);
                        return ptr.__newindex(L);
                    }
                }.inner;

                luaState.pushClosure(zlua.wrap(newIndexFunc), 0);
                luaState.setField(-2, "__newindex");
            } else {
                // If no index func was given, use our own that indexes to ourself
                const indexFunc = struct {
                    fn inner(L: *zlua.Lua) i32 {
                        return indexSetValueFunc(T, L, meta_table_name);
                    }
                }.inner;

                luaState.pushClosure(zlua.wrap(indexFunc), 0);
                luaState.setField(-2, "__newindex");
            }

            // Now wire up our functions!
            const found_fns = comptime findLibraryFunctions(T, bound_type.ignore_fields);
            inline for (found_fns) |foundFunc| {
                luaState.pushClosure(foundFunc.func.?, 0);
                luaState.setField(-2, foundFunc.name);
            }

            // Make this usable with "require" and register our funcs in the library
            luaState.requireF(meta_table_name, zlua.wrap(makeLuaOpenLibAndBindFn(T, found_fns, bound_type.ignore_fields)), true);
            luaState.pop(3);

            debug.log("Bound lua type: '{any}' to '{s}'", .{ T, meta_table_name });

            if (startTop != luaState.getTop()) {
                debug.fatal("Lua binding: leaking stack!", .{});
            }
        }

        pub fn bindLibrary(luaState: *zlua.Lua, libraryName: [:0]const u8, comptime funcs: []const zlua.FnReg) void {
            luaState.requireF(libraryName, zlua.wrap(makeLuaOpenLibFn(funcs)), true);
        }

        pub fn makeLuaBinding(name: [:0]const u8, comptime function: anytype) zlua.FnReg {
            return zlua.FnReg{ .name = name, .func = zlua.wrap(bindFuncLua(name, function)) };
        }

        pub fn findLibraryFunctions(comptime module: anytype, ignore_fields: []const [:0]const u8) []const zlua.FnReg {
            comptime {
                const fn_fields = findFunctions(module, ignore_fields);

                var found: []const zlua.FnReg = &[_]zlua.FnReg{};
                for (fn_fields) |d| {
                    // convert the name string to be :0 terminated
                    const field_name: [:0]const u8 = d.name ++ "";
                    found = found ++ .{makeLuaBinding(field_name, @field(module, d.name))};
                }

                return found;
            }
        }

        pub fn bindFuncLua(comptime name: [:0]const u8, comptime function: anytype) fn (lua: *Lua) i32 {
            return (opaque {
                pub fn lua_call(luaState: *Lua) i32 {
                    const FnType = @TypeOf(function);

                    // Can't bind types with anytype, so early out if we see one!
                    if (comptime hasAnytypeParam(FnType)) {
                        debug.warning("Cannot call bound function with anytype param", .{});
                        return 0;
                    }

                    // Get a tuple of the various types of the arguments, and then create one
                    const ArgsTuple = std.meta.ArgsTuple(FnType);
                    var args: ArgsTuple = undefined;

                    const fn_info = @typeInfo(@TypeOf(function)).@"fn";
                    const params = fn_info.params;

                    inline for (params, 0..) |param, i| {
                        const param_type = param.type.?;
                        const lua_idx = i + 1;

                        args[i] = toAny(luaState, param_type, lua_idx) catch {
                            debug.warning("Lua: '{s}': Could not bind arg {any} to {any}", .{ name, lua_idx, param_type });
                            luaState.raiseErrorStr("Could not bind argument! Should be type %s", .{@typeName(param_type)});
                            return 0;
                        };
                    }

                    if (fn_info.return_type == null) {
                        @compileError("Function has no return type?! This should not be possible.");
                    }

                    const ReturnType = fn_info.return_type.?;

                    // Handle both error union and non-error union function calls
                    const ret_val = switch (@typeInfo(ReturnType)) {
                        .error_union => |_| blk: {
                            const val = @call(.auto, function, args) catch |err| {
                                debug.warning("Error returned from bound Lua function: {any}", .{err});
                                return 0;
                            };

                            break :blk val;
                        },
                        else => @call(.auto, function, args),
                    };

                    return pushAny(luaState, ret_val);
                }
            }).lua_call;
        }

        // Like ziglua pushAny, but also handling our registered types
        pub fn pushAny(luaState: *Lua, value: anytype) i32 {
            const val_type = @TypeOf(value);

            // Push the value onto the stack

            switch (@typeInfo(val_type)) {
                .void => {
                    return 0;
                },
                .array => {
                    luaState.createTable(0, 0);
                    for (value, 0..) |index_value, i| {
                        _ = luaState.pushInteger(@intCast(i + 1));
                        _ = pushAny(luaState, index_value);
                        luaState.setTable(-3);
                    }
                    return 1;
                },
                .vector => |info| {
                    _ = pushAny(luaState, @as([info.len]info.child, value));
                    return 1;
                },
                .@"struct" => {
                    // handle our registered auto-bound struct types
                    if (comptime isRegistered(val_type)) {
                        // make a new ptr
                        const ptr: *val_type = @alignCast(luaState.newUserdata(val_type, @sizeOf(val_type)));

                        // set its metatable
                        _ = luaState.getMetatableRegistry(getMetaTableName(val_type));
                        _ = luaState.setMetatable(-2);

                        // copy values to our pointer
                        ptr.* = value;
                        return 1;
                    }
                },
                else => {},
            }

            // Fall back to the ziglua pushAny
            _ = luaState.pushAny(value) catch |err| {
                debug.fatal("Error pushing value onto Lua stack! {any}", .{err});
                return 0;
            };

            return 1;
        }

        pub fn toAny(luaState: *Lua, comptime T: type, lua_idx: i32) !T {
            switch (@typeInfo(T)) {
                .pointer => |p| {
                    const Child = p.child;
                    if (p.size == .one and isRegistered(Child)) {
                        // If we're a registered type, check if we're a light userdata first
                        if (luaState.isLightUserdata(lua_idx)) {
                            return try luaState.toUserdata(Child, lua_idx);
                        } else {
                            // Not a light userdata, so must be a full userdata
                            return luaState.checkUserdata(Child, lua_idx, getMetaTableName(Child));
                        }
                    } else {
                        // Not a registered type, fallback to the default toAny
                        return try luaState.toAny(T, lua_idx);
                    }
                },
                .array, .vector => {
                    const child = std.meta.Child(T);
                    const arr_len = switch (@typeInfo(T)) {
                        inline else => |i| i.len,
                    };

                    var result: [arr_len]child = undefined;
                    luaState.pushValue(lua_idx);
                    defer luaState.pop(1);

                    for (0..arr_len) |i| {
                        _ = luaState.rawGetIndex(-1, @intCast(i + 1));
                        defer luaState.pop(1);
                        result[i] = try toAny(luaState, child, -1);
                    }

                    return result;
                },
                else => {
                    if (isRegistered(T)) {
                        return luaState.checkUserdata(T, lua_idx, getMetaTableName(T)).*;
                    }
                    // Fallback to the default toAny
                    return try luaState.toAny(T, lua_idx);
                },
            }
        }

        pub fn makeLuaOpenLibFn(lib_funcs: []const zlua.FnReg) fn (*Lua) i32 {
            return opaque {
                pub fn inner(luaState: *Lua) i32 {
                    // Register our new library for this type, with all our funcs!
                    luaState.newLib(lib_funcs);
                    return 1;
                }
            }.inner;
        }

        pub fn makeLuaOpenLibAndBindFn(comptime module: anytype, lib_funcs: []const zlua.FnReg, ignore_fields: []const [:0]const u8) fn (*Lua) i32 {
            return opaque {
                pub fn inner(luaState: *Lua) i32 {
                    // Register our new library for this type, with all our funcs!
                    luaState.newLib(lib_funcs);

                    // Also register our constant fields, like Vec2.one
                    const found_fields = comptime findFields(module, ignore_fields);

                    inline for (found_fields) |field| {
                        _ = pushAny(luaState, @field(module, field.name));
                        luaState.setField(-2, field.name);
                    }

                    return 1;
                }
            }.inner;
        }
    };
}

pub fn isErrorUnionType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .error_union => true,
        else => false,
    };
}

fn hasAnytypeParam(comptime T: type) bool {
    const fn_info = @typeInfo(T).@"fn";

    inline for (fn_info.params) |p| {
        if (p.type == null) return true;
        if (@hasField(@TypeOf(p), "is_generic") and p.is_generic) return true;
    }
    return false;
}

pub fn shouldIgnoreField(field_name: [:0]const u8, ignore_fields: []const [:0]const u8) bool {
    if (field_name.len == 0 or field_name[0] == '_') {
        return true;
    }

    for (ignore_fields) |toIgnore| {
        if (std.mem.eql(u8, field_name, toIgnore)) {
            return true;
        }
    }

    return false;
}

fn findFunctions(comptime module: anytype, ignore_fields: []const [:0]const u8) []const std.builtin.Type.Declaration {
    comptime {
        // Get all the public declarations in this module
        const decls = @typeInfo(module).@"struct".decls;

        // filter out only the public functions
        var gen_fields: []const std.builtin.Type.Declaration = &[_]std.builtin.Type.Declaration{};
        for (decls) |d| {
            if (shouldIgnoreField(d.name, ignore_fields))
                continue;

            const field = @field(module, d.name);
            if (@typeInfo(@TypeOf(field)) != .@"fn")
                continue;

            gen_fields = gen_fields ++ .{d};
        }

        return gen_fields;
    }
}

fn findFields(comptime module: anytype, ignore_fields: []const [:0]const u8) []const std.builtin.Type.Declaration {
    comptime {
        // Get all the public declarations in this module
        const decls = @typeInfo(module).@"struct".decls;

        // filter out only the public constants
        var gen_fields: []const std.builtin.Type.Declaration = &[_]std.builtin.Type.Declaration{};
        for (decls) |d| {
            if (shouldIgnoreField(d.name, ignore_fields))
                continue;

            const field = @field(module, d.name);
            if (@typeInfo(@TypeOf(field)) == .@"fn")
                continue;

            // Now filter out just the contants
            if (@typeInfo(@TypeOf(&field)).pointer.is_const) {
                gen_fields = gen_fields ++ .{d};
            }
        }

        return gen_fields;
    }
}
