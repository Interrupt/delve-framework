const debug = @import("../debug.zig");
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;

pub const Vector2 = struct {
    x: f32,
    y: f32,
};

pub const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,
};

var default_pass_action: sg.PassAction = .{};

pub fn init() !void {
    debug.log("Graphics subsystem starting", .{});

    default_pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 1, .g = 1, .b = 0, .a = 1 },
    };
}

pub fn deinit() void {
    debug.log("Graphics subsystem stopping", .{});
}

pub fn startFrame() void {
    // Animate the background just to have something showing!
    const g = default_pass_action.colors[0].clear_value.g + 0.01;
    default_pass_action.colors[0].clear_value.g = if (g > 1.0) 0.0 else g;
    sg.beginDefaultPass(default_pass_action, sapp.width(), sapp.height());
    sg.endPass();
    sg.commit();
}

pub fn endFrame() void {
    debug.drawConsole();
}

pub fn clear(color: Color) void {
    _ = color;

    // clear_pass_action.colors[0].clear_value.r = color.r;
    // clear_pass_action.colors[0].clear_value.g = color.g;
    // clear_pass_action.colors[0].clear_value.b = color.b;
    // clear_pass_action.colors[0].clear_value.a = 1.0;

    // sg.beginDefaultPass(clear_pass_action, sapp.width(), sapp.height());
    // sg.endPass();
    // sg.commit();
}

pub fn line(start: Vector2, end: Vector2, color: Color) void {
    _ = start;
    _ = end;
    _ = color;
    // const renderer = zigsdl.getRenderer();
    // _ = sdl.SDL_SetRenderDrawColor(renderer, @intFromFloat(color.r), @intFromFloat(color.g), @intFromFloat(color.b), 0xFF);
    // _ = sdl.SDL_RenderDrawLine(renderer, @intFromFloat(start.x), @intFromFloat(start.y), @intFromFloat(end.x), @intFromFloat(end.y));
}
