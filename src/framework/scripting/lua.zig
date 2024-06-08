const ziglua = @import("ziglua");
const std = @import("std");
const debug = @import("../debug.zig");
const mem = @import("../mem.zig");

const Lua = ziglua.Lua;

// Allocator for the Lua VM
var lua_arena: std.heap.ArenaAllocator = undefined;
var lua_allocator: std.mem.Allocator = undefined;

// Global Lua state
var lua: *Lua = undefined;

// Enable for extra logging
var enable_debug_logging = false;

pub fn init() !void {
    debug.log("Lua: system starting up!", .{});

    lua_arena = std.heap.ArenaAllocator.init(mem.getAllocator());
    lua_allocator = lua_arena.allocator();

    // Initialize the Lua VM!
    lua = try Lua.init(&lua_allocator);

    // Turn on to get lua debug output
    if (enable_debug_logging)
        setDebugHook();

    lua.openLibs(); // open standard libs

    debug.log("Lua: ready to go!", .{});
}

pub fn runFile(lua_filename: [:0]const u8) !void {
    debug.log("Lua: running file {s}", .{lua_filename});

    defer lua.setTop(0);
    lua.doFile(lua_filename) catch |err| {
        const lua_error = lua.toString(-1) catch {
            debug.log("Lua: could not get error string", .{});
            return err;
        };

        debug.log("Lua: error running file {s}: {s}", .{ lua_filename, lua_error });
        return err;
    };
}

pub fn runLine(lua_string: [:0]const u8) !void {
    // Compile the new line
    lua.loadString(lua_string) catch |err| {
        debug.log("{s}", .{try lua.toString(-1)});
        lua.pop(1);
        return err;
    };

    // Execute the new line
    lua.protectedCall(0, 0, 0) catch |err| {
        debug.log("{s}", .{try lua.toString(-1)});
        lua.pop(1);
        return err;
    };
}

pub fn openModule(comptime name: [:0]const u8, comptime open_func: ziglua.ZigFn) void {
    lua.requireF(name, ziglua.wrap(open_func), true);
    debug.log("Lua: registered module '{s}'", .{name});
}

pub fn callFunction(func_name: [:0]const u8) !void {
    if (enable_debug_logging)
        debug.log("Lua: calling {s}", .{func_name});

    _ = lua.getGlobal(func_name) catch {
        if (enable_debug_logging)
            debug.log("Lua: no global {s} found to call", .{func_name});

        lua.pop(1);
        return;
    };

    if (!lua.isFunction(1)) {
        if (enable_debug_logging)
            debug.log("Lua: no function {s} found to call", .{func_name});

        lua.pop(1);
        return;
    }

    lua.protectedCall(0, 0, 0) catch |err| {
        debug.log("Lua: error calling func {s}: {!s} {}", .{ func_name, lua.toString(-1), err });
        lua.pop(1);
        return err;
    };
}

pub fn setDebugHook() void {
    // create a debug hook to print state
    const hook = struct {
        fn inner(l: *Lua, event: ziglua.Event, i: *ziglua.DebugInfo) void {
            const type_name = switch (event) {
                .call => "call",
                .line => "line",
                .ret => "ret",
                else => unreachable,
            };

            l.getInfo(.{
                .l = true,
                .r = true,
                .n = true,
                .S = true,
            }, i);
            debug.log("LuaDebug: {s} ({s}:{?d} {?s} {})", .{ type_name, i.source, i.current_line, i.name, i.what });
        }
    }.inner;

    lua.setHook(ziglua.wrap(hook), .{ .call = true, .line = true, .ret = true }, 0);
}

fn printDebug() void {
    const lua_debug = lua.getStack(1);
    if (lua_debug) |stack| {
        debug.log("Lua: stack debug: {?s} {?s}.", .{ stack.source, stack.name });
    } else |err| {
        debug.log("Lua: stack is empty {}.", .{err});
    }
}

pub fn deinit() void {
    debug.log("Lua: shutting down", .{});

    // Close the Lua state and free memory
    lua.deinit();
    lua_arena.deinit();
}
