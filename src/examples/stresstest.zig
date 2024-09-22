const std = @import("std");
const delve = @import("delve");
const app = delve.app;

const fps_module = delve.module.fps_counter;
const audio_example = @import("audio.zig");
const debugdraw_example = @import("debugdraw.zig");
const meshes_example = @import("meshes.zig");
const skinnedmeshes_example = @import("skinned-meshes.zig");
const sprites_example = @import("sprites.zig");
const forest_example = @import("forest.zig");
const fonts_example = @import("fonts.zig");
const animation_example = @import("sprite-animation.zig");
const imgui_example = @import("imgui.zig");

const lua_module = delve.module.lua_simple;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// This example loads a bunch of the examples to stress test everything!
// Also a good example of how the module system can be used to compose apps

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
    try audio_example.registerModule();
    try debugdraw_example.registerModule();
    try meshes_example.registerModule();
    try lua_module.registerModule();
    try sprites_example.registerModule();
    try imgui_example.registerModule();
    try fonts_example.registerModule();
    try animation_example.registerModule();
    try skinnedmeshes_example.registerModule();
    // try forest_example.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Stress Test", .enable_audio = true });
}
