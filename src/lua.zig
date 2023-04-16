const ziglua = @import("ziglua");
const std = @import("std");

// Modules
const draw_module = @import("draw.zig");
const mouse_module = @import("mouse.zig");

const Lua = ziglua.Lua;

// LUA VM allocator
var lua_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var lua: *Lua = undefined;

pub fn initLua(luaFileString: [:0]const u8) !void {
    std.debug.print("Lua module starting up\n", .{});

    // Create an allocator
    const allocator = lua_gpa.allocator();

    // Initialize the Lua VM!
    lua = @constCast(&(try Lua.init(allocator)));

    // Open the standard libraries
    lua.openLibs();

    draw_module.registerModule(lua);
    mouse_module.registerModule(lua);

    // Load the file into lua
    //try lua.loadFile(luaFileString, ziglua.Mode.text);
    lua.doFile(luaFileString) catch |err| {
        std.debug.print("lua error! output: {!s} {}\n", .{lua.toString(-1), err});
        return err;
    };

    std.debug.print("Loaded lua file {s}\n", .{luaFileString});
}

pub fn runInit() !void {
    std.debug.print("Lua: Running _init\n", .{});

    // Call the "_main" function!
    _ = try lua.getGlobal("_init");
    lua.call(0, 0);
    
    std.debug.print("lua error! output: {!s}\n", .{lua.toString(-1)});
}

pub fn deinitLua() void {
    std.debug.print("Lua module shutdown\n", .{});
    _ = lua.deinit();
    _ = lua_gpa.deinit();
}
