const debug = @import("../debug.zig");
const zigsdl = @import("../sdl.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub fn init() ! void {
    debug.log("Input subsystem starting", .{});
}

pub fn deinit() void {
    debug.log("Input subsystem stopping", .{});
}

pub fn processInput() void {
    zigsdl.processEvents();
}
