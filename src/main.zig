const std = @import("std");

// Delve framework
const app = @import("app.zig");

const zaudio = @import("zaudio");

var args_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var args_allocator = args_gpa.allocator();

pub fn main() !void {
    // Get arguments
    const args = try std.process.argsAlloc(args_allocator);
    defer _ = args_gpa.deinit();
    defer std.process.argsFree(args_allocator, args);

    // Set a different assets path if one is given
    if(args.len >= 2) {
        try app.setAssetsPath(args[1]);
    }

    zaudio.init(args_allocator);
    defer zaudio.deinit();

    const engine = try zaudio.Engine.create(null);
    defer engine.destroy();

    const music = try engine.createSoundFromFile(
        "assets/" ++ "sample-9s.mp3",
        .{ .flags = .{ .stream = true, .async_load = true } },
    );

    music.setVolume(0.5);
    music.setPitch(1.0);
    music.setLooping(true);

    defer music.destroy();
    try music.start();

    // Test some example modules
    try @import("examples/debugdraw.zig").registerModule();
    try @import("examples/batcher.zig").registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework Test" });
}
