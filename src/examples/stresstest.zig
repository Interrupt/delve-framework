const delve = @import("delve");
const app = delve.app;

const fps_module = delve.module_fps_counter;
const audio_example = @import("audio.zig");
const debugdraw_example = @import("debugdraw.zig");
const meshes_example = @import("meshes.zig");
const sprites_example = @import("sprites.zig");
const forest_example = @import("forest.zig");

// This example loads a bunch of the examples to stress test everything!
// Also a good example of how the module system can be used to compose apps

pub fn main() !void {
    try fps_module.registerModule();
    try audio_example.registerModule();
    try debugdraw_example.registerModule();
    try meshes_example.registerModule();
    try sprites_example.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Stress Test" });
}
