const delve = @import("delve");
const app = delve.app;

const audio_example = @import("audio.zig");
const debugdraw_example = @import("debugdraw.zig");
const meshes_example = @import("meshes.zig");
const sprites_example = @import("sprites.zig");

// This example loads all of the examples to stress test everything!
// Also a good example of how the module system can be used to compose apps

pub fn main() !void {
    try audio_example.registerModule();
    try debugdraw_example.registerModule();
    try meshes_example.registerModule();
    try sprites_example.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Stress Test" });
}
