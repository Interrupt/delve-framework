const std = @import("std");
const debug = @import("../debug.zig");

const zlua = @import("zlua");
const Lua = zlua.Lua;

const LuaError = error{
    SliceNotSupported,
};

pub const BoundType = struct {
    Type: type,
    name: [:0]const u8,
    ignore_fields: []const [:0]const u8 = &[_][:0]const u8{},
    mixin: ?type = null,
};

pub const RegistryConfig = struct {
    entries: []const BoundType,
    ignored_types: ?[]const type = null,
};

pub fn Registry(comptime cfg: RegistryConfig) type {
    return struct {
        pub const registry = cfg.entries;
        pub const ignored_types = cfg.ignored_types;

        // Allow us to box up our bound types
        pub fn BoxType(comptime T: type, comptime in_bound_type: BoundType) type {
            return struct {
                const Self = @This();
                pub const bound_type: BoundType = in_bound_type;
                pub const ptr_metatable_name = in_bound_type.name ++ "_ptr";

                pointer: *T,

                pub fn checkBoxedUserdata(luaState: *Lua, lua_idx: i32) *T {
                    // First check if this is a boxed pointer, unbox and return if so
                    if (luaState.testUserdata(Self, lua_idx, ptr_metatable_name)) |boxed_ptr| {
                        return boxed_ptr.*.pointer;
                    } else |_| {}

                    // Not a boxed pointer, should be already unboxed
                    return luaState.checkUserdata(T, lua_idx, in_bound_type.name);
                }
            };
        }

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

        pub fn getBoundType(comptime T: type) ?BoundType {
            inline for (registry) |entry| {
                if (entry.Type == T) return entry;
            }
            return null;
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
            const start_top = luaState.getTop();

            // Bind our functions first
            inline for (registry) |entry| {
                try bindType(luaState, entry);
            }

            // Now add in our static properties to the created libraries
            inline for (registry) |entry| {
                try bindStaticProperties(luaState, entry);
            }

            // make sure we're not leaking stack
            const end_top = luaState.getTop();
            if (start_top != end_top) {
                debug.fatal("Lua bindTypes: leaking stack! s: {d} e: {d}", .{ start_top, end_top });
            }
        }

        // __index is called when Lua gets a value from a table
        pub fn indexLookupFunc(comptime T: type, luaState: *Lua, bound_type: BoundType) i32 {
            const BoxedPointerType = BoxType(T, bound_type);

            // Get our key
            const key = luaState.toString(-1) catch |err| {
                debug.fatal("Lua: indexLookupFunc could not get key! {s}: {any}", .{ bound_type.name, err });
                return 0;
            };

            const ptr = BoxedPointerType.checkBoxedUserdata(luaState, 1);

            // Grab this field if we find it
            inline for (std.meta.fields(T)) |field| {
                const should_ignore = comptime shouldIgnoreTypeOrField(field.type, field.name, bound_type.ignore_fields, ignored_types);

                if (std.mem.eql(u8, key, field.name)) {
                    if (should_ignore) {
                        debug.warning("Lua: Cannot get field '{s}' from '{s}' because it is ignored", .{ field.name, bound_type.name });
                        luaState.pushNil();
                        return 1;
                    } else {
                        const val = @field(ptr, field.name);
                        return pushAny(luaState, val);
                    }
                }
            }

            // fallback to our own metatable so that we can still call bound functions like self:ourFunc()

            // get our own metatable
            _ = luaState.getMetatableRegistry(bound_type.name);

            // push the key again
            luaState.pushValue(2);

            // return metatable[key]
            _ = luaState.getTable(-2);

            return 1;
        }

        // __newindex is called when Lua sets a value on a table
        pub fn indexSetValueFunc(comptime T: type, luaState: *Lua, bound_type: BoundType) i32 {
            const BoxedPointerType = BoxType(T, bound_type);

            // Get our key
            const key = luaState.toString(-2) catch |err| {
                debug.fatal("Lua: indexLookupFunc could not get key! {s}: {any}", .{ bound_type.name, err });
                return 0;
            };

            // If this is a userdata object, check if it has this property
            if (luaState.isUserdata(1)) {
                const ptr = BoxedPointerType.checkBoxedUserdata(luaState, 1);

                // Set this field if we find it
                inline for (std.meta.fields(T)) |field| {
                    const should_ignore = comptime shouldIgnoreTypeOrField(field.type, field.name, bound_type.ignore_fields, ignored_types);

                    if (std.mem.eql(u8, key, field.name)) {
                        if (should_ignore) {
                            debug.warning("Lua: Cannot set field '{s}' from '{s}' because it is ignored", .{ field.name, bound_type.name });
                            return 0;
                        } else {
                            const val = toAny(luaState, field.type, -1) catch {
                                luaState.raiseErrorStr("Could not set field! Should be type %s", .{@typeName(field.type)});
                                return 0;
                            };

                            @field(ptr, field.name) = val;
                            return 1;
                        }
                    }
                }
            }

            debug.warning("Lua: {s}: Could not find field '{s}' to set", .{ bound_type.name, key });
            return 0;
        }

        pub fn bindStaticProperties(luaState: *zlua.Lua, comptime bound_type: BoundType) !void {
            const meta_table_name = bound_type.name;

            const start_top = luaState.getTop();

            // Get our library
            _ = try luaState.getGlobal(meta_table_name);

            // Register any constant fields, like Vec2.one
            const found_fields = comptime findFields(bound_type.Type, bound_type.ignore_fields, ignored_types);

            inline for (found_fields) |field| {
                const val = @field(bound_type.Type, field.name);
                _ = pushAny(luaState, val);

                luaState.setField(-2, field.name);
            }

            // Reset state
            luaState.pop(1);

            const end_top = luaState.getTop();
            if (start_top != end_top) {
                debug.fatal("Lua property binding: leaking stack! s: {d} e: {d}", .{ start_top, end_top });
            }
        }

        pub fn bindType(luaState: *zlua.Lua, comptime bound_type: BoundType) !void {
            const T = bound_type.Type;
            const meta_table_name = bound_type.name;
            const BoxedPointerType = BoxType(T, bound_type);

            const startTop = luaState.getTop();

            // Make our boxed pointer type
            _ = luaState.newUserdata(BoxedPointerType, @sizeOf(BoxedPointerType));
            _ = try luaState.newMetatable(BoxedPointerType.ptr_metatable_name);

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
                        const ptr = BoxedPointerType.checkBoxedUserdata(L, 1);
                        return ptr.__index(L);
                    }
                }.inner;

                const wrapped_fn = zlua.wrap(indexFunc);

                // Set on boxed metatable
                luaState.pushClosure(wrapped_fn, 0);
                luaState.setField(-4, "__index");

                // Set on struct metatable
                luaState.pushClosure(wrapped_fn, 0);
                luaState.setField(-2, "__index");
            } else {
                // If no index func was given, use our own that indexes to ourself
                const indexFunc = struct {
                    fn inner(L: *zlua.Lua) i32 {
                        return indexLookupFunc(T, L, bound_type);
                    }
                }.inner;

                const wrapped_fn = zlua.wrap(indexFunc);

                // Set on boxed metatable
                luaState.pushClosure(wrapped_fn, 0);
                luaState.setField(-4, "__index");

                // Set on struct metatable
                luaState.pushClosure(wrapped_fn, 0);
                luaState.setField(-2, "__index");
            }

            if (comptime hasNewIndexFunc(T)) {
                // Wire to __newindex in lua
                const newIndexFunc = struct {
                    fn inner(L: *zlua.Lua) i32 {
                        const ptr = BoxedPointerType.checkBoxedUserdata(L, 1);
                        return ptr.__newindex(L);
                    }
                }.inner;

                const wrapped_fn = zlua.wrap(newIndexFunc);

                // Set on boxed metatable
                luaState.pushClosure(wrapped_fn, 0);
                luaState.setField(-4, "__newindex");

                // Set on struct metatable
                luaState.pushClosure(wrapped_fn, 0);
                luaState.setField(-2, "__newindex");
            } else {
                // If no index func was given, use our own that indexes to ourself
                const indexFunc = struct {
                    fn inner(L: *zlua.Lua) i32 {
                        return indexSetValueFunc(T, L, bound_type);
                    }
                }.inner;

                const wrapped_fn = zlua.wrap(indexFunc);

                // Set on boxed metatable
                luaState.pushClosure(wrapped_fn, 0);
                luaState.setField(-4, "__newindex");

                // Set on struct metatable
                luaState.pushClosure(wrapped_fn, 0);
                luaState.setField(-2, "__newindex");
            }

            // Now wire up our functions!
            const library_fns = comptime findLibraryFunctions(T, bound_type.ignore_fields);

            // also add in our mixin
            const mixin_fns = comptime findLibraryFunctionsOpt(bound_type.mixin, bound_type.ignore_fields);
            const found_fns = library_fns ++ mixin_fns;

            inline for (found_fns) |foundFunc| {
                luaState.pushClosure(foundFunc.func.?, 0);
                luaState.setField(-2, foundFunc.name);
            }

            // Make this usable with "require" and register our funcs in the library
            luaState.requireF(meta_table_name, zlua.wrap(makeLuaOpenLibAndBindFn(found_fns)), true);
            luaState.pop(3);

            // Pop boxed metatable
            luaState.pop(2);

            debug.log("Bound lua type: '{any}' to '{s}'", .{ T, meta_table_name });

            const end_top = luaState.getTop();
            if (startTop != end_top) {
                debug.fatal("Lua binding: leaking stack! s: {d} e: {d}", .{ startTop, end_top });
            }
        }

        pub fn bindLibrary(luaState: *zlua.Lua, libraryName: [:0]const u8, comptime funcs: []const zlua.FnReg) void {
            luaState.requireF(libraryName, zlua.wrap(makeLuaOpenLibFn(funcs)), true);
        }

        pub fn makeLuaBinding(name: [:0]const u8, mod_name: [:0]const u8, comptime function: anytype) zlua.FnReg {
            return zlua.FnReg{ .name = name, .func = zlua.wrap(bindFuncLua(name, mod_name, function)) };
        }

        pub fn findLibraryFunctionsOpt(comptime module: ?type, ignore_fields: []const [:0]const u8) []const zlua.FnReg {
            if (module) |m| {
                return findLibraryFunctions(m, ignore_fields);
            }
            return &[_]zlua.FnReg{};
        }

        pub fn findLibraryFunctions(comptime module: anytype, ignore_fields: []const [:0]const u8) []const zlua.FnReg {
            comptime {
                const fn_fields = findFunctions(module, ignore_fields);

                var found: []const zlua.FnReg = &[_]zlua.FnReg{};
                for (fn_fields) |d| {
                    // convert the name string to be :0 terminated
                    const field_name: [:0]const u8 = d.name ++ "";
                    found = found ++ .{makeLuaBinding(field_name, @typeName(module), @field(module, d.name))};
                }

                return found;
            }
        }

        pub fn bindFuncLua(comptime name: [:0]const u8, comptime mod_name: [:0]const u8, comptime function: anytype) fn (lua: *Lua) i32 {
            return (opaque {
                pub fn lua_call(luaState: *Lua) i32 {
                    const FnType = @TypeOf(function);

                    const top = luaState.getTop();

                    // Can't bind types with anytype, so early out if we see one!
                    if (comptime hasAnytypeParam(FnType)) {
                        debug.warning("Lua: Cannot call bound function '{s}:{s}' with anytype param", .{ mod_name, name });
                        return 0;
                    }
                    if (comptime hasIgnoredTypeParam(FnType, ignored_types)) {
                        debug.warning("Lua: Cannot call bound function '{s}:{s}' with ignored type param", .{ mod_name, name });
                        return 0;
                    }

                    // Get a tuple of the various types of the arguments, and then create one
                    const ArgsTuple = std.meta.ArgsTuple(FnType);
                    var args: ArgsTuple = undefined;

                    const fn_info = @typeInfo(@TypeOf(function)).@"fn";
                    const params = fn_info.params;

                    // Validate number of args
                    if (top != params.len) {
                        const ignore_default = params.len == 0 and top == 1; // could just be our self ref

                        if (!ignore_default) {
                            debug.warning("Lua: function '{s}:{s}' called with {d} arguments called with {d} instead", .{ mod_name, name, params.len, top });
                            luaState.raiseErrorStr("Invalid number of arguments to function", .{});
                            return 0;
                        }
                    }

                    inline for (params, 0..) |param, i| {
                        const param_type = param.type.?;
                        const lua_idx = i + 1;

                        args[i] = toAny(luaState, param_type, lua_idx) catch {
                            debug.warning("Lua: '{s}:{s}': Could not bind arg {any} to {any}", .{ mod_name, name, lua_idx, param_type });
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
                .optional, .null => {
                    if (value == null) {
                        luaState.pushNil();
                    } else {
                        _ = pushAny(luaState, value.?);
                    }
                    return 1;
                },
                .pointer => |p| {
                    const Child = p.child;
                    if (p.size == .one) {
                        // Explode if this is a const we can't handle!
                        if (p.is_const) {
                            debug.fatal("Lua: Cannot push const pointer! Cannot guarantee that references will not be modified", .{});
                            return 0;
                        }

                        // If this is a pointer of a bound type, box it up
                        if (getBoundType(Child)) |bound_type| {
                            const BoxedPointerType = BoxType(Child, bound_type);
                            const boxed_ptr: BoxedPointerType = .{ .pointer = value };

                            // make a new ptr to return
                            const ptr: *BoxedPointerType = @alignCast(luaState.newUserdata(BoxedPointerType, @sizeOf(BoxedPointerType)));

                            // set its metatable
                            _ = luaState.getMetatableRegistry(BoxedPointerType.ptr_metatable_name);
                            _ = luaState.setMetatable(-2);

                            // copy values to our pointer
                            ptr.* = boxed_ptr;

                            return 1;
                        }
                    }
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

        fn isTypeString(typeinfo: std.builtin.Type.Pointer) bool {
            const childinfo = @typeInfo(typeinfo.child);
            if (typeinfo.child == u8 and typeinfo.size != .one) {
                return true;
            } else if (typeinfo.size == .one and childinfo == .array and childinfo.array.child == u8) {
                return true;
            }
            return false;
        }

        pub fn toAny(luaState: *Lua, comptime T: type, lua_idx: i32) !T {
            switch (@typeInfo(T)) {
                .pointer => |p| {
                    const Child = p.child;
                    if (p.size == .one) {
                        // If this is a pointer of a bound type, try to unbox it
                        if (getBoundType(Child)) |bound_type| {
                            const BoxedPointerType = BoxType(Child, bound_type);
                            return BoxedPointerType.checkBoxedUserdata(luaState, lua_idx);
                        }
                    }

                    if (comptime isTypeString(p)) {
                        // Found a string!
                        const string: [*:0]const u8 = try luaState.toString(lua_idx);
                        return std.mem.span(string);
                    } else {
                        switch (p.size) {
                            .slice, .many => {
                                return LuaError.SliceNotSupported;
                            },
                            else => {},
                        }
                    }

                    return try luaState.toAny(T, lua_idx);
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
                .optional => {
                    if (luaState.isNil(lua_idx)) {
                        return null;
                    } else {
                        return try toAny(luaState, @typeInfo(T).optional.child, lua_idx);
                    }
                },
                else => {
                    // Might be a registered type
                    if (getBoundType(T)) |bound_type| {
                        // May need to unbox it
                        const BoxedPointerType = BoxType(T, bound_type);
                        return BoxedPointerType.checkBoxedUserdata(luaState, lua_idx).*;
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

        pub fn makeLuaOpenLibAndBindFn(lib_funcs: []const zlua.FnReg) fn (*Lua) i32 {
            return opaque {
                pub fn inner(luaState: *Lua) i32 {
                    // Register our new library for this type, with all our funcs!
                    luaState.newLib(lib_funcs);

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

fn hasIgnoredTypeParam(comptime T: type, comptime ignored_fields: ?[]const type) bool {
    const fn_info = @typeInfo(T).@"fn";

    inline for (fn_info.params) |p| {
        if (p.type == null) return true;
        if (shouldIgnoreType(p.type.?, ignored_fields)) return true;
    }
    return false;
}

fn shouldIgnoreTypeOrField(field_type: type, field_name: [:0]const u8, ignore_fields: []const [:0]const u8, ignore_types: ?[]const type) bool {
    // Some types should be outright ignored
    if (shouldIgnoreType(field_type, ignore_types)) {
        return true;
    }

    // might still be ignored by name
    return shouldIgnoreField(field_name, ignore_fields);
}

fn shouldIgnoreField(field_name: [:0]const u8, ignore_fields: []const [:0]const u8) bool {
    // Ignore private fields
    if (field_name.len == 0 or field_name[0] == '_') {
        return true;
    }

    // Now check the ignore_fields list
    for (ignore_fields) |toIgnore| {
        if (std.mem.eql(u8, field_name, toIgnore)) {
            return true;
        }
    }

    return false;
}

fn shouldIgnoreType(comptime T: type, comptime ignored_types: ?[]const type) bool {
    if (ignored_types) |types| {
        inline for (types) |t| {
            if (t == T)
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

fn findFields(comptime module: anytype, ignore_fields: []const [:0]const u8, ignore_types: ?[]const type) []const std.builtin.Type.Declaration {
    comptime {
        // Get all the public declarations in this module
        const decls = @typeInfo(module).@"struct".decls;

        // filter out only the public constants
        var gen_fields: []const std.builtin.Type.Declaration = &[_]std.builtin.Type.Declaration{};
        for (decls) |d| {
            if (shouldIgnoreField(d.name, ignore_fields))
                continue;

            const field = @field(module, d.name);
            const field_type = @TypeOf(field);

            if (@typeInfo(field_type) == .@"fn")
                continue;

            if (shouldIgnoreType(field_type, ignore_types))
                continue;

            // Now filter out just the contants
            if (@typeInfo(@TypeOf(&field)).pointer.is_const) {
                gen_fields = gen_fields ++ .{d};
            }
        }

        return gen_fields;
    }
}
