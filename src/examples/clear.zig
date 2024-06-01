const delve = @import("delve");
const app = delve.app;
const std = @import("std");
const builtin = @import("builtin");

// This example does nothing but open a blank window!

// EMSCRIPTEN HACK! See https://github.com/ziglang/zig/issues/19072
pub const os = if (builtin.os.tag != .wasi and builtin.os.tag != .emscripten) std.os else struct {
    pub const heap = struct {
        pub const page_allocator = std.heap.c_allocator;
    };
};

pub fn main() !void {
    std.debug.print("starting clear example\n", .{});

    const clear_module = delve.modules.Module{
        .name = "clear_example",
        .init_fn = on_init,
    };

    std.debug.print("1\n", .{});

    try delve.modules.registerModule(clear_module);

    std.debug.print("2\n", .{});

    try app.start(app.AppConfig{ .title = "Delve Framework - Clear Example" });

    std.debug.print("3\n", .{});
}

pub fn on_init() !void {
    std.debug.print("clear module on_init()\n", .{});
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_light);
}
