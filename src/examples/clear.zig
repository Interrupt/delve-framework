const delve = @import("delve");
const app = delve.app;
const std = @import("std");

// This example does nothing but open a blank window!

var time: f32 = 0.0;

pub fn main() !void {
    const clear_module = delve.modules.Module{
        .name = "clear_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .on_resize_fn = on_resize,
    };

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

    try delve.modules.registerModule(clear_module);

    try app.start(app.AppConfig{ .title = "Delve Framework - Clear Example" });
}

pub fn on_init() !void {
    delve.debug.log("Clear Example Initializing", .{});
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_light);
}

pub fn on_tick(delta: f32) void {
    time += delta;

    if (delve.platform.input.isKeyJustPressed(.ESCAPE)) {
        delve.platform.app.exit();
    }

    var bg_color = delve.colors.examples_bg_light;
    bg_color.r = (@sin(time * 2.0) + 1.0) * 0.5;
    bg_color.g = (@sin(time * 2.3) + 1.0) * 0.5;
    bg_color.b = (@sin(time * 2.5) + 1.0) * 0.5;

    delve.platform.graphics.setClearColor(bg_color);
}

pub fn on_resize() !void {
    // Could call some resize logic here if needed
}
