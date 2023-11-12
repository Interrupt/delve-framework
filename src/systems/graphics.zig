const zigsdl = @import("../sdl.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

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

pub fn clear(color: Color) void {
    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, @intFromFloat(color.r), @intFromFloat(color.g), @intFromFloat(color.b), 0xFF);
    _ = sdl.SDL_RenderClear(renderer);
}

pub fn line(start: Vector2, end: Vector2, color: Color) void {
    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, @intFromFloat(color.r), @intFromFloat(color.g), @intFromFloat(color.b), 0xFF);
    _ = sdl.SDL_RenderDrawLine(renderer, @intFromFloat(start.x), @intFromFloat(start.y), @intFromFloat(end.x), @intFromFloat(end.y));
}
