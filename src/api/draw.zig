const std = @import("std");
const ziglua = @import("ziglua");
const app = @import("../app.zig");
const debug = @import("../debug.zig");
const text_module = @import("text.zig");
const math = @import("../math.zig");
const graphics = @import("../platform/graphics.zig");
const batcher = @import("../graphics/batcher.zig");

const Vec2 = @import("../math.zig").Vec2;

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

/// Called at the start of a frame
pub fn libTick(tick: u64) void {
    _ = tick;
    shape_batch.reset();
}

/// Called at the end of a frame
pub fn libDraw() void {
    var view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 5 }, math.Vec3.zero(), math.Vec3.up());
    var model = math.Mat4.translate(.{ .x = 0.0, .y = 0.0, .z = -2.5 });

    graphics.setProjectionOrtho(0.001, 10.0, true);
    graphics.setView(view, model);

    shape_batch.apply();
    shape_batch.draw();
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

    // Four bytes per color
    var color_idx = pal_color * app.palette.channels;

    if (color_idx >= app.palette.height * app.palette.pitch)
        color_idx = app.palette.pitch - 4;

    const r = app.palette.raw[color_idx];
    const g = app.palette.raw[color_idx + 1];
    const b = app.palette.raw[color_idx + 2];

    const color: graphics.Color = graphics.Color{
        .r = @floatFromInt(r),
        .g = @floatFromInt(g),
        .b = @floatFromInt(b),
    };

    graphics.setClearColor(color);
}

pub fn line(start_x :f32, start_y: f32, end_x: f32, end_y: f32, line_width: f32, pal_color: u32) void {
    if (enable_debug_logging)
        debug.log("Draw: line({d},{d},{d},{d},{d})", .{ start_x, start_y, end_x, end_y, pal_color });

    // Four bytes per color
    var color_idx = pal_color * app.palette.channels;

    if (color_idx >= app.palette.height * app.palette.pitch)
        color_idx = app.palette.pitch - 4;

    const r = app.palette.raw[color_idx];
    const g = app.palette.raw[color_idx + 1];
    const b = app.palette.raw[color_idx + 2];

    const color: graphics.Color = graphics.Color{
        .r = @floatFromInt(r),
        .g = @floatFromInt(g),
        .b = @floatFromInt(b),
    };

    const start = Vec2 { .x = start_x, .y = start_y };
    const end = Vec2 { .x = end_x, .y = end_y };

    shape_batch.addLine(Vec2.mul(start, 1.0), Vec2.mul(end, 1.0), line_width, batcher.TextureRegion.default(), color.toInt());
}

pub fn filled_circle(x: f32, y: f32, radius: f32, pal_color: u32) void {
    _ = x;
    _ = y;

    // Four bytes per color
    var color_idx = pal_color * app.palette.channels;

    if (color_idx >= app.palette.height * app.palette.pitch)
        color_idx = app.palette.pitch - 4;

    // const r = app.palette.raw[color_idx];
    // const g = app.palette.raw[color_idx + 1];
    // const b = app.palette.raw[color_idx + 2];

    // const renderer = zigsdl.getRenderer();
    // _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF);

    // Dissapear when too small
    if (radius <= 0.25)
        return;

    // In the easy case, just plot a pixel
    if (radius <= 0.5) {
        // _ = sdl.SDL_RenderDrawPoint(renderer, @intFromFloat(x), @intFromFloat(y));
        return;
    }

    // Harder case, draw the circle in vertical strips
    // Can figure out the height of the strip based on the xpos via good old pythagoros
    // Y = 2 * sqrt(R^2 - X^2)
    var x_idx: f64 = -radius;
    while (x_idx < 1) : (x_idx += 1) {
        var offset = std.math.sqrt(std.math.pow(f64, radius, 2) - std.math.pow(f64, x_idx, 2));
        var y_idx: f64 = -offset;
        if (offset <= 0.5)
            continue;

        _ = y_idx;

        offset = std.math.round(offset);

        // Draw mirrored sides!
        // while (y_idx < offset) : (y_idx += 1) {
        //     _ = sdl.SDL_RenderDrawPoint(renderer, @intFromFloat(x + x_idx), @intFromFloat(y + y_idx));
        //     if (x + x_idx != x - x_idx and x_idx <= 0)
        //         _ = sdl.SDL_RenderDrawPoint(renderer, @intFromFloat(x - x_idx), @intFromFloat(y + y_idx));
        // }
    }
}

pub fn rectangle(start_x: f32, start_y: f32, width: f32, height: f32, line_width: f32, pal_color: u32) void {
    // Four bytes per color
    var color_idx = pal_color * app.palette.channels;

    if (color_idx >= app.palette.height * app.palette.pitch)
        color_idx = app.palette.pitch - 4;

    const r = app.palette.raw[color_idx];
    const g = app.palette.raw[color_idx + 1];
    const b = app.palette.raw[color_idx + 2];

    const color: graphics.Color = graphics.Color{
        .r = @floatFromInt(r),
        .g = @floatFromInt(g),
        .b = @floatFromInt(b),
    };

    const pos = Vec2.new(start_x, start_y);
    const size = Vec2.new(width, height);

    shape_batch.addLineRectangle(pos, size, line_width, batcher.TextureRegion.default(), color.toInt());
}

pub fn filled_rectangle(start_x: f32, start_y: f32, width: f32, height: f32, pal_color: u32) void {
    // Four bytes per color
    var color_idx = pal_color * app.palette.channels;

    if (color_idx >= app.palette.height * app.palette.pitch)
        color_idx = app.palette.pitch - 4;

    const r = @as(f32, @floatFromInt(app.palette.raw[color_idx])) / 256.0;
    const g = @as(f32, @floatFromInt(app.palette.raw[color_idx + 1])) / 256.0;
    const b = @as(f32, @floatFromInt(app.palette.raw[color_idx + 2])) / 256.0;

    const color = graphics.Color{ .r = r, .g = g, .b = b, .a = 1.0 };

    const pos = Vec2.new(start_x, start_y);
    const size = Vec2.new(width, height);

    shape_batch.addRectangle(pos, size, batcher.TextureRegion.default(), color.toInt());
}

pub fn text(text_string: [*:0]const u8, x_pos: i32, y_pos: i32, color_idx: u32) void {
    text_module.draw(text_string, x_pos, y_pos, color_idx);
}
