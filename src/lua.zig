const ziglua = @import("ziglua");
const std = @import("std");

const Lua = ziglua.Lua;

// Allocator for the Lua VM
var lua_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var lua_allocator = lua_gpa.allocator();

// Global Lua state
var lua: Lua = undefined;

// Enable for extra logging
var enable_debug_logging = false;

pub fn init() !void {
    std.debug.print("Lua: system starting up!\n", .{});

    // Initialize the Lua VM!
    lua = try Lua.init(lua_allocator);

    // Turn on to get lua debug output
    if(enable_debug_logging)
        setDebugHook();

    lua.openLibs(); // open standard libs
    openModules();  // open custom modules

    std.debug.print("Lua: ready to go!\n", .{});
}

pub fn runFile(lua_filename: [:0]const u8) !void {
    std.debug.print("Lua: running file {s}\n", .{lua_filename});

    defer lua.setTop(0);
    lua.doFile(lua_filename) catch |err| {
        std.debug.print("Lua: runFile error in {s}: {!s} {}\n", .{lua_filename, lua.toString(-1), err});
        return err;
    };
}

fn openModule(comptime name: [:0]const u8, comptime open_func: ziglua.ZigFn) void {
    lua.requireF(name, ziglua.wrap(open_func), true);
    std.debug.print("Lua: registered module '{s}'\n", .{name});
}

fn openModules() void {
    // Open all of the API modules here!
    openModule("assets", @import("modules/assets.zig").makeLib);
    openModule("display", @import("modules/display.zig").makeLib);
    openModule("draw", @import("modules/draw.zig").makeLib);
    openModule("input.mouse", @import("modules/mouse.zig").makeLib);
    openModule("text", @import("modules/text.zig").makeLib);
}

pub fn callFunction(func_name: [:0]const u8) !void {

    if(enable_debug_logging)
        std.debug.print("Lua: calling {s}\n", .{func_name});

    _ = lua.getGlobal(func_name) catch {
        if(enable_debug_logging)
            std.debug.print("Lua: no global {s} found to call\n", .{func_name});

        lua.pop(1);
        return;
    };

    if(!lua.isFunction(1)) {
        if(enable_debug_logging)
            std.debug.print("Lua: no function {s} found to call\n", .{func_name});

        lua.pop(1);
        return;
    }

    lua.protectedCall(0, 0, 0) catch |err| {
        std.debug.print("Lua: pCall error! output: {!s} {}\n", .{lua.toString(-1), err});
        return err;
    };
}

pub fn setDebugHook() void {
    // create a debug hook to print state
    const hook = struct {
        fn inner(l: *Lua, event: ziglua.Event, i: *ziglua.DebugInfo) void {
            var type_name = switch (event) {
                .call => "call",
                .line => "line",
                .ret => "ret",
                else => unreachable,
            };

            l.getInfo(.{ .l = true, .r = true, .n = true, .S = true, }, i);
            std.debug.print("LuaDebug: {s} ({s}:{?d} {?s} {})\n", .{type_name, i.source, i.current_line, i.name, i.what});
        }
    }.inner;

    lua.setHook(ziglua.wrap(hook), .{ .call = true, .line = true, .ret = true }, 0);
}

fn printDebug() void {
    var lua_debug = lua.getStack(1);
    if(lua_debug) |debug| {
        std.debug.print("Lua: stack debug: {?s} {?s}.\n", .{debug.source, debug.name});
    } else |err| {
        std.debug.print("Lua: stack is empty {}.\n", .{err});
    }
}

pub fn deinit() void {
    std.debug.print("Lua: shutting down\n", .{});

    // Close the Lua state and free memory
    lua.deinit();
    _ = lua_gpa.deinit();
}
