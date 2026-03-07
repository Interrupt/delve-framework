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
                debug.warning("Lua: indexLookupFunc could not get key! {s}: {any}", .{ meta_table_name, err });
                return 0;
            };

            // If this is a userdata object, check if it has this property
            if (luaState.isUserdata(1)) {
                const ptr = luaState.checkUserdata(T, 1, meta_table_name);

                // Grab this field if we find it
                inline for (std.meta.fields(T)) |field| {
                    if (std.mem.eql(u8, key, field.name)) {
                        const val = @field(ptr, field.name);
                        const ret_type = @TypeOf(val);

                        // handle registered auto-bound struct types
                        if (comptime isRegistered(ret_type)) {
                            // make a new ptr
                            const new_ptr: *ret_type = @alignCast(luaState.newUserdata(ret_type, @sizeOf(ret_type)));

                            // set its metatable
                            _ = luaState.getMetatableRegistry(getMetaTableName(ret_type));
                            _ = luaState.setMetatable(-2);

                            // copy values to our pointer
                            new_ptr.* = val;
                            return 1;
                        }

                        _ = luaState.pushAny(val) catch |err| {
                            debug.warning("Could not push field {s}: {any}", .{ field.name, err });
                            return 0;
                        };

                        return 1;
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
            }

            // Now wire up our functions!
            const found_fns = comptime findLibraryFunctions(T, bound_type.ignore_fields);
            inline for (found_fns) |foundFunc| {
                luaState.pushClosure(foundFunc.func.?, 0);
                luaState.setField(-2, foundFunc.name);
            }

            // Make this usable with "require" and register our funcs in the library
            luaState.requireF(meta_table_name, zlua.wrap(makeLuaOpenLibFn(found_fns)), true);
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

        pub fn findLibraryFunctions(comptime module: anytype, ignoreFunctions: []const [:0]const u8) []const zlua.FnReg {
            comptime {
                // Get all the public declarations in this module
                const decls = @typeInfo(module).@"struct".decls;
                // filter out only the public functions
                var gen_fields: []const std.builtin.Type.Declaration = &[_]std.builtin.Type.Declaration{};
                for (decls) |d| {
                    const field = @field(module, d.name);
                    if (@typeInfo(@TypeOf(field)) == .@"fn") {
                        gen_fields = gen_fields ++ .{d};
                    }
                }

                var found: []const zlua.FnReg = &[_]zlua.FnReg{};
                for (gen_fields) |d| {
                    // convert the name string to be :0 terminated
                    const field_name: [:0]const u8 = d.name ++ "";

                    // Might need to ignore some functions by name
                    if (shouldIgnoreFunction(field_name, ignoreFunctions)) {
                        continue;
                    }

                    found = found ++ .{makeLuaBinding(field_name, @field(module, d.name))};
                }
                return found;
            }
        }

        pub fn shouldIgnoreFunction(fn_name: [:0]const u8, ignoreFunctions: []const [:0]const u8) bool {
            if (fn_name.len == 0 or fn_name[0] == '_') {
                return true;
            }

            for (ignoreFunctions) |toIgnore| {
                if (std.mem.eql(u8, fn_name, toIgnore)) {
                    return true;
                }
            }

            return false;
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

                        switch (@typeInfo(param_type)) {
                            .pointer => |p| {
                                const Child = p.child;
                                if (p.size == .one and isRegistered(Child)) {
                                    // If we're a registered type, check if we're a light userdata first
                                    if (luaState.isLightUserdata(lua_idx)) {
                                        args[i] = luaState.toUserdata(Child, lua_idx) catch {
                                            debug.fatal("Lua: '{s}': Could not convert arg {any} to userdata {any}", .{ name, lua_idx, param_type });
                                            return 0;
                                        };
                                    } else {
                                        // Not a light userdata, so must be a full userdata
                                        args[i] = luaState.checkUserdata(Child, lua_idx, getMetaTableName(Child));
                                    }
                                } else {
                                    // Not a registered type, fallback to the default toAny
                                    args[i] = luaState.toAny(param_type, lua_idx) catch {
                                        debug.fatal("Lua: '{s}': Could not convert arg {any} to type {any}", .{ name, lua_idx, param_type });
                                        return 0;
                                    };
                                }
                            },
                            else => {
                                // debug.warning("Found param type: {any}", .{param_type});
                                args[i] = luaState.toAny(param_type, lua_idx) catch {
                                    debug.fatal("Lua: '{s}': Could not convert arg {any} to type {any}", .{ name, lua_idx, param_type });
                                    return 0;
                                };
                            },
                        }
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

                    const ret_type = @TypeOf(ret_val);

                    // handle registered auto-bound struct types
                    if (comptime isRegistered(ret_type)) {
                        // make a new ptr
                        const ptr: *ret_type = @alignCast(luaState.newUserdata(ret_type, @sizeOf(ret_type)));

                        // set its metatable
                        _ = luaState.getMetatableRegistry(getMetaTableName(ret_type));
                        _ = luaState.setMetatable(-2);

                        // copy values to our pointer
                        ptr.* = ret_val;
                        return 1;
                    }

                    switch (@TypeOf(ret_val)) {
                        std.meta.Tuple(&.{ f32, f32 }) => {
                            // probably is a way to handle any tuple types
                            luaState.pushNumber(ret_val[0]);
                            luaState.pushNumber(ret_val[1]);
                            return 2;
                        },
                        else => {},
                    }

                    // Push the return value onto the stack
                    luaState.pushAny(ret_val) catch |err| {
                        debug.fatal("Error pushing value onto Lua stack! {any}", .{err});
                        return 0;
                    };

                    // Should either be one item, or none
                    switch (ret_type) {
                        void => {
                            return 0;
                        },
                        else => {
                            return 1;
                        },
                    }

                    @compileError("LUA did not return number of return values correctly!");
                }
            }).lua_call;
        }
    };
}

pub fn isModuleFunction(comptime name: [:0]const u8, comptime in_type: anytype) bool {
    // Don't try to bind the script lib lifecycle functions!
    if (std.mem.eql(u8, name, "libInit") or std.mem.eql(u8, name, "libTick") or std.mem.eql(u8, name, "libDraw") or std.mem.eql(u8, name, "libCleanup"))
        return false;

    // Hide some other functions that start with '_'
    if (name[0] == '_')
        return false;

    return @typeInfo(in_type) == .@"fn";
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

fn makeFuncRg(funcs: []zlua.CFn) []zlua.FnReg {
    comptime {
        const registry = [_]zlua.FnReg{};

        for (funcs) |func| {
            const newRegFn = zlua.FnReg{ .name = "new", .func = func };
            registry ++ newRegFn;
        }

        return registry;
    }
}

pub fn makeLuaOpenLibFn(libFuncs: []const zlua.FnReg) fn (*Lua) i32 {
    return opaque {
        pub fn inner(luaState: *Lua) i32 {
            // Register our new library for this type, with all our funcs!
            luaState.newLib(libFuncs);

            return 1;
        }
    }.inner;
}
