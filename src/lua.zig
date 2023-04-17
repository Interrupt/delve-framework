const ziglua = @import("ziglua");
const std = @import("std");

// Modules
const draw_module = @import("modules/draw.zig");
const mouse_module = @import("modules/mouse.zig");

const Lua = ziglua.Lua;

// Allocator for the Lua VM
var lua_gpa = std.heap.GeneralPurposeAllocator(.{}){};

// Global Lua state
var lua: *Lua = undefined;

pub fn init(luaFileString: [:0]const u8) !void {
    std.debug.print("Lua: system starting up!\n", .{});

    // Create an allocator
    const allocator = lua_gpa.allocator();

    // Initialize the Lua VM!
    lua = @constCast(&(try Lua.init(allocator)));

    lua.openLibs(); // open standard libs
    openModules();  // open custom modules

    // Load and run the file
    lua.doFile(luaFileString) catch |err| {
        std.debug.print("Lua: doFile error! output: {!s} {}\n", .{lua.toString(-1), err});
        return err;
    };

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
    std.debug.print("Lua: calling {s}\n", .{func_name});

    _ = lua.getGlobal(func_name) catch |err| {
        std.debug.print("Lua: getGlobal error! output: {!s} {}\n", .{lua.toString(-1), err});
        return err;
    };

    lua.protectedCall(0, 0, 0) catch |err| {
        std.debug.print("Lua: pCall error! output: {!s} {}\n", .{lua.toString(-1), err});
        return err;
    };
}

pub fn deinit() void {
    std.debug.print("Lua: shutting down\n", .{});

    // Close the Lua state
    lua.close();

    // Now we can deinit
    _ = lua.deinit();
    _ = lua_gpa.deinit();
}
