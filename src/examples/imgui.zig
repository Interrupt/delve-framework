const delve = @import("delve");
const app = delve.app;
const std = @import("std");

const imgui = delve.imgui;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// This example shows how to use Dear Imgui!

const imgui_module = delve.modules.Module{
    .name = "imgui_example",
    .init_fn = on_init,
    .tick_fn = on_tick,
    .draw_fn = on_draw,
};

var bg_color: [4]f32 = [4]f32{ 0.25, 0.85, 0.55, 1.0 };

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

    try registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Imgui Example" });
}

pub fn registerModule() !void {
    try delve.modules.registerModule(imgui_module);
}

pub fn on_init() !void {
    delve.debug.log("Imgui Example Initializing.", .{});
}

pub fn on_tick(delta: f32) void {
    _ = delta;

    if (delve.platform.input.isKeyJustPressed(.ESCAPE)) {
        delve.platform.app.exit();
    }

    delve.platform.app.startImguiFrame();

    imgui.igSetNextWindowPos(.{ .x = 40, .y = 60 }, imgui.ImGuiCond_Once, .{ .x = 0, .y = 0 });
    imgui.igSetNextWindowSize(.{ .x = 400, .y = 100 }, imgui.ImGuiCond_Once);
    _ = imgui.igBegin("Hello Dear ImGui!", 0, imgui.ImGuiWindowFlags_None);
    _ = imgui.igColorEdit3("Background", &bg_color[0], imgui.ImGuiColorEditFlags_None);
    imgui.igEnd();

    delve.platform.graphics.setClearColor(delve.colors.Color.fromArray(bg_color));
}

pub fn on_draw() void {
    delve.platform.app.renderImgui();
}
