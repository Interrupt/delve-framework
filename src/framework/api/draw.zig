const std = @import("std");
const ziglua = @import("ziglua");
const app = @import("../app.zig");
const papp = @import("../platform/app.zig");
const debug = @import("../debug.zig");
const colors = @import("../colors.zig");
const text_module = @import("text.zig");
const math = @import("../math.zig");
const graphics = @import("../platform/graphics.zig");
const batcher = @import("../graphics/batcher.zig");
const sprites = @import("../graphics/sprites.zig");

const Vec2 = @import("../math.zig").Vec2;
const Rect = @import("../spatial/rect.zig").Rect;

var shape_batch: batcher.Batcher = undefined;

var enable_debug_logging = false;

// ------- Lifecycle functions --------
/// Called when the app is starting up
pub fn libInit() void {
    shape_batch = batcher.Batcher.init(.{}) catch {
        debug.log("Error initializing shape batch!", .{});
        return;
    };
}

/// Called just before drawing
pub fn libPreDraw() void {
    shape_batch.reset();
}

/// Called when ready to draw
pub fn libDraw() void {
    var view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 5 }, math.Vec3.zero, math.Vec3.up);
    var proj = graphics.getProjectionOrtho(0.001, 10.0, true);
    var model = math.Mat4.translate(.{ .x = 0.0, .y = 0.0, .z = -2.5 });

    shape_batch.apply();
    shape_batch.draw(proj.mul(view), model);
}

/// Called when things are shutting down
pub fn libCleanup() void {
    debug.log("Draw: cleanup", .{});
    shape_batch.deinit();
}

// ------- API functions --------
/// Sets the clear color
pub fn clear(pal_color: u32) void {
    if (enable_debug_logging)
        debug.log("Draw: clear {d}", .{pal_color});

    const color = colorFromPalette(pal_color);
    graphics.setClearColor(color);
}

pub fn line(start_x: f32, start_y: f32, end_x: f32, end_y: f32, line_width: f32, pal_color: u32) void {
    if (enable_debug_logging)
        debug.log("Draw: line({d},{d},{d},{d},{d})", .{ start_x, start_y, end_x, end_y, pal_color });

    const start = Vec2{ .x = start_x, .y = start_y };
    const end = Vec2{ .x = end_x, .y = end_y };
    const color = colorFromPalette(pal_color);

    shape_batch.addLine(start, end, line_width, sprites.TextureRegion.default(), color);
}

pub fn filled_circle(x: f32, y: f32, radius: f32, pal_color: u32) void {
    const pos = Vec2{ .x = x, .y = y };
    const color = colorFromPalette(pal_color);

    shape_batch.addCircle(pos, radius, 16, sprites.TextureRegion.default(), color);
}

pub fn circle(x: f32, y: f32, radius: f32, line_width: f32, pal_color: u32) void {
    const pos = Vec2{ .x = x, .y = y };
    const color = colorFromPalette(pal_color);

    shape_batch.addLineCircle(pos, radius, 16, line_width, sprites.TextureRegion.default(), color);
}

pub fn rectangle(start_x: f32, start_y: f32, width: f32, height: f32, line_width: f32, pal_color: u32) void {
    const pos = Vec2.new(start_x, start_y);
    const size = Vec2.new(width, height);
    const color = colorFromPalette(pal_color);

    shape_batch.addLineRectangle(Rect.new(pos, size), line_width, sprites.TextureRegion.default(), color);
}

pub fn filled_rectangle(start_x: f32, start_y: f32, width: f32, height: f32, pal_color: u32) void {
    const pos = Vec2.new(start_x, start_y);
    const size = Vec2.new(width, height);
    const color = colorFromPalette(pal_color);

    shape_batch.addRectangle(Rect.new(pos, size), sprites.TextureRegion.default(), color);
}

pub fn text(text_string: [*:0]const u8, x_pos: i32, y_pos: i32, color_idx: u32) void {
    text_module.draw(text_string, x_pos, y_pos, color_idx);
}

fn colorFromPalette(pal_color: u32) graphics.Color {
    return colors.getColorFromPalette(pal_color);
}
