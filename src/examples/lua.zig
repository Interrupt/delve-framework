const delve = @import("delve");
const app = delve.app;

const lua_module = delve.module.lua_simple;
const fps_module = delve.module.fps_counter;

// This example shows how to integrate with lua scripting

pub fn main() !void {
    try lua_module.registerModule();
    try fps_module.registerModule();
    try app.start(app.AppConfig{ .title = "Delve Framework - Lua Example" });
}
