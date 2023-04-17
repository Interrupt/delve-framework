const ziglua = @import("ziglua");
const std = @import("std");

// Modules
const draw_module = @import("draw.zig");
const mouse_module = @import("mouse.zig");

const Lua = ziglua.Lua;

// Allocator for the Lua VM
var lua_gpa = std.heap.GeneralPurposeAllocator(.{}){};

// Global Lua state
var lua: *Lua = undefined;

pub fn initLua(luaFileString: [:0]const u8) !void {
    std.debug.print("Lua system starting up\n", .{});

    // Create an allocator
    const allocator = lua_gpa.allocator();

    // Initialize the Lua VM!
    lua = @constCast(&(try Lua.init(allocator)));

    lua.openLibs(); // open standard libs
    openModules();  // open custom modules

    // Load and run the file
    lua.doFile(luaFileString) catch |err| {
        std.debug.print("Lua doFile error! output: {!s} {}\n", .{lua.toString(-1), err});
        return err;
    };

    std.debug.print("Lua system: loaded file {s}\n", .{luaFileString});
}

pub fn openModules() void {
    // Open all of the custom modules here
    draw_module.openModule(lua);
    mouse_module.openModule(lua);
}

pub fn callFunction(func_name: [:0]const u8) !void {
    std.debug.print("Lua system: calling {s}\n", .{func_name});

    _ = lua.getGlobal(func_name) catch |err| {
        std.debug.print("Lua getGlobal error! output: {!s} {}\n", .{lua.toString(-1), err});
        return err;
    };

    lua.protectedCall(0, 0, 0) catch |err| {
        std.debug.print("Lua pCall error! output: {!s} {}\n", .{lua.toString(-1), err});
        return err;
    };
}

pub fn deinitLua() void {
    std.debug.print("Lua system shutdown\n", .{});
    _ = lua.deinit();
    _ = lua_gpa.deinit();
}
