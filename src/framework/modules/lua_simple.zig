const debug = @import("../debug.zig");
const lua = @import("../scripting/lua.zig");
const scripting_manager = @import("../scripting/manager.zig");
const modules = @import("../modules.zig");

// This is a module that emulates a Pico-8 style simple app.
// It will call _init on startup, _update on tick, _draw when drawing,
// and _shutdown at the end.

/// Registers this module
pub fn registerModule() !void {
    const luaSimpleLifecycle = modules.Module{
        .name = "lua_simple_lifecycle",
        .start_fn = on_game_start,
        .stop_fn = on_game_stop,
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
        .priority = modules.Priority.first,
    };

    try modules.registerModule(luaSimpleLifecycle);
}

pub fn on_init() !void {
    // start up the scripting manager!
    try debug.registerConsoleCommand("lua", doLuaCommand, "Runs Lua string");
    try scripting_manager.init();
}

pub fn on_game_start() void {
    debug.log("Starting simple Lua lifecycle...", .{});

    // Load and run the main script
    lua.runFile("assets/main.lua") catch {
        debug.showErrorScreen("Fatal error!");
        return;
    };

    // Call the init lifecycle function
    lua.callFunction("_init") catch {
        debug.showErrorScreen("Fatal error!");
    };
}

pub fn on_game_stop() void {
    debug.log("Simple Lua lifecycle stopping", .{});

    // Call the shutdown lifecycle function
    lua.callFunction("_shutdown") catch {
        debug.log("Error calling lua _shutdown", .{});
    };
}

pub fn on_cleanup() !void {
    scripting_manager.deinit();
}

pub fn on_tick(delta: f32) void {
    _ = delta;

    lua.callFunction("_update") catch {
        debug.showErrorScreen("Fatal error!");
    };
}

pub fn on_draw() void {
    lua.callFunction("_draw") catch {
        debug.showErrorScreen("Fatal error!");
    };
}

// console command to run a lua string
pub fn doLuaCommand(lua_command: [:0]const u8) void {
    if (lua.did_init) {
        lua.runLine(lua_command) catch {};
    } else {
        debug.log("Lua is not yet initialized.", .{});
    }
}
