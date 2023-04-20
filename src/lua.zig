const ziglua = @import("ziglua");
const std = @import("std");

// Modules
const draw_module = @import("modules/draw.zig");
const mouse_module = @import("modules/mouse.zig");

const Lua = ziglua.Lua;

// Allocator for the Lua VM
var lua_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var lua_allocator = lua_gpa.allocator();

// Global Lua state
var lua: Lua = undefined;

// Enable for extra logging
var enable_debug_logging = false;

pub fn init(luaFileString: [:0]const u8) !void {
    std.debug.print("Lua: system starting up!\n", .{});
    std.debug.print("Lua: opening file {s}\n", .{luaFileString});

    // Initialize the Lua VM!
    lua = try Lua.init(lua_allocator);

    // Turn on to get lua debug output
    //setDebugHook();

    lua.openLibs(); // open standard libs
    openModules();  // open custom modules

    // Load and run the file
    lua.doFile(luaFileString) catch |err| {
        std.debug.print("Lua: doFile error! output: {!s} {}\n", .{lua.toString(-1), err});
        return err;
    };

    // Clear stack after running
    lua.setTop(0);

    std.debug.print("Lua: loaded file {s}\n", .{luaFileString});
}

pub fn openModule(comptime name: [:0]const u8, comptime open_func: ziglua.ZigFn) void {
    lua.requireF(name, ziglua.wrap(open_func), true);
}

pub fn openModules() void {
    // Open all of the custom modules here
    openModule("draw", draw_module.makeLib);
    openModule("input.mouse", mouse_module.makeLib);
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

pub fn printDebug() void {
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
