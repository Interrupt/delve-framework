const delve = @import("delve");
const app = delve.app;
const std = @import("std");
const builtin = @import("builtin");

// This example does nothing but open a blank window!

pub fn main() !void {
    std.debug.print("starting clear example\n", .{});

    const clear_module = delve.modules.Module{
        .name = "clear_example",
        .init_fn = on_init,
    };

    // Pick the allocator to use depending on platform
    if (builtin.os.tag == .wasi or builtin.os.tag == .emscripten) {
        // Web builds hack: use the C allocator to avoid OOM errors
        // See https://github.com/ziglang/zig/issues/19072
        try delve.init(std.heap.c_allocator);
    } else {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        try delve.init(gpa.allocator());
    }

    try delve.modules.registerModule(clear_module);

    try app.start(app.AppConfig{ .title = "Delve Framework - Clear Example" });
}

pub fn on_init() !void {
    std.debug.print("clear module on_init()\n", .{});
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_light);
}
