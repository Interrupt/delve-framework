const std = @import("std");
const delve = @import("delve");
const app = delve.app;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const lua_module = delve.module.lua_simple;
const fps_module = delve.module.fps_counter;

// This example shows how to integrate with lua scripting

pub const TestBindingStruct = struct {
    message: []const u8,

    pub fn new(in_message: []const u8) TestBindingStruct {
        return .{ .message = in_message };
    }

    pub fn sayHello(self: *TestBindingStruct) void {
        delve.debug.log(" > Test Lua Binding says: {s}", .{self.message});
    }

    pub fn getMessage(self: *TestBindingStruct) []const u8 {
        return self.message;
    }

    pub fn ignoreMe() void {}

    pub fn destroy(self: *TestBindingStruct) void {
        _ = self;
        delve.debug.log("TestBindingStruct cleanup called from Lua gc", .{});
    }
};

pub fn main() !void {
    // Pick the allocator to use depending on platform
    const builtin = @import("builtin");
    if (builtin.os.tag == .wasi or builtin.os.tag == .emscripten) {
        // Web builds hack: use the C allocator to avoid OOM errors
        // See https://github.com/ziglang/zig/issues/19072
        try delve.init(std.heap.c_allocator);
    } else {
        // Using the default allocator will let us detect memory leaks
        try delve.init(delve.mem.createDefaultAllocator());
    }

    try fps_module.registerModule();

    // The simple lua module emulates a Pico-8 style app.
    // It will call the lua file's _init on startup, _update on tick, _draw when drawing,
    // and _shutdown at the end.
    try lua_module.registerModule("assets/main.lua");

    // Make a new module to run our test lua line!
    // This will compile and run a print line
    const lua_test_module = delve.modules.Module{
        .name = "lua_test_module",
        .init_fn = lua_test_on_init,
    };
    try delve.modules.registerModule(lua_test_module);

    try app.start(app.AppConfig{ .title = "Delve Framework - Lua Example" });
}

pub fn lua_test_on_init() !void {
    // Get the lua state to interact with Lua manually
    const lua = delve.scripting.lua.getLua();

    // Register some types with Lua so we can interact with them on the Lua side
    const registry = delve.scripting.binder.Registry(&[_]delve.scripting.binder.BoundType{
        .{ .Type = TestBindingStruct, .name = "TestStruct", .ignore_fns = &[_][:0]const u8{"ignoreMe"} },
    });
    try registry.bindTypes(lua);

    // Load and run a Lua string
    try runLuaPrintLine(lua);
}

pub fn runLuaPrintLine(lua: *delve.scripting.lua.Lua) !void {
    const lua_string = "print('This is a print from our new manually compiled lua file!')";

    lua.loadString(lua_string) catch |err| {
        delve.debug.log("{s}", .{try lua.toString(-1)});
        lua.pop(1);
        return err;
    };

    // Execute the new line
    lua.protectedCall(.{ .args = 0 }) catch |err| {
        delve.debug.log("{s}", .{try lua.toString(-1)});
        lua.pop(1);
        return err;
    };
}
