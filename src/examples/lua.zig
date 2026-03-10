const std = @import("std");
const delve = @import("delve");
const app = delve.app;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const lua_module = delve.module.lua_simple;
const fps_module = delve.module.fps_counter;

// This example shows how to use lua scripting

pub const TestBindingStruct = struct {
    message: []const u8,

    pub fn new(in_message: []const u8) TestBindingStruct {
        return .{ .message = in_message };
    }

    pub fn getSelf(self: *TestBindingStruct) *TestBindingStruct {
        return self;
    }

    pub fn sayHello(self: *TestBindingStruct) void {
        delve.debug.log(" > Test Lua Binding says: {s}", .{self.message});
    }

    pub fn getMessage(self: *TestBindingStruct) []const u8 {
        return self.message;
    }

    pub fn testOptional(self: ?*TestBindingStruct) ?TestBindingStruct {
        return self.?.*;
    }

    pub fn ignoreMe() void {
        @compileError("This field should be ignored during binding!");
    }

    // Lua garbage collection will automatically call destroy if found
    pub fn destroy(self: *TestBindingStruct) void {
        _ = self;
        delve.debug.log("TestBindingStruct cleanup called from Lua gc", .{});
    }

    pub const constant_message: [:0]const u8 = "This is a constant!";
};

const testBindingScript =
    \\ -- Test out binding Zig structs and using them in Lua
    \\ local TestStruct = require("TestStruct")
    \\ print(TestStruct.constant_message)
    \\ local test_binding = TestStruct.new("Hello from Lua!")
    \\ test_binding:sayHello()
    \\ test_binding:testOptional()
    \\ local title = test_binding:getMessage()
    \\ print(" > Message from Zig: " .. title)
    \\ -- Set and get fields
    \\ test_binding.message = "Updated value"
    \\ print("Message: " .. test_binding.message)
    \\ local title = test_binding:getMessage()
    \\ -- Pointer types
    \\ local test_pointer = test_binding:getSelf() 
    \\ test_pointer:sayHello()
    \\ test_pointer.message = "Set from a pointer"
    \\ test_pointer:sayHello()
    \\ print("Message: " .. test_pointer.message)
;

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

    // Make a new module to test some other Lua functions
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

    // You can register structs with Lua so we can interact with them on the Lua side!
    const registry = delve.scripting.binder.Registry(&[_]delve.scripting.binder.BoundType{
        .{ .Type = TestBindingStruct, .name = "TestStruct", .ignore_fields = &[_][:0]const u8{"ignoreMe"} },
    });
    try registry.bindTypes(lua);

    // Load and run a simple Lua command
    try runLuaString(lua, "print('This is a print from our new manually compiled lua file!')");

    // Run a string that exercises our struct binding
    try runLuaString(lua, testBindingScript);
}

pub fn runLuaString(lua: *delve.scripting.lua.Lua, lua_string: [:0]const u8) !void {
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
