const colors = @import("../../../colors.zig");
const debug = @import("../../../debug.zig");
const graphics = @import("../../graphics.zig");

pub fn init() !void {
    debug.log("Sokol null graphics backend starting", .{});
}

pub fn startFrame() void {}

pub fn endFrame() void {}

pub fn deinit() void {}

pub fn setClearColor(color: colors.Color) void {
    _ = color;
}

pub fn beginPass(render_pass: graphics.RenderPass, clear_color: ?colors.Color) void {
    _ = render_pass;
    _ = clear_color;
}

pub fn endPass() void {}

/// Sets the debug text drawing color
pub fn setDebugTextColor(color: colors.Color) void {
    _ = color;
}

/// Draws debug text on the screen
pub fn drawDebugText(x: f32, y: f32, str: [:0]const u8) void {
    _ = x;
    _ = y;
    _ = str;
}

/// Draws a single debug text character
pub fn drawDebugTextChar(x: f32, y: f32, char: u8) void {
    _ = x;
    _ = y;
    _ = char;
}

/// Sets the scaling used when drawing debug text
pub fn setDebugTextScale(scale: f32) void {
    _ = scale;
}

/// Returns the current text scale for debug text
pub fn getDebugTextScale() f32 {
    return 1.0;
}
