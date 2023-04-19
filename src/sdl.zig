const std = @import("std");
const main = @import("main.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

var window: *sdl.SDL_Window = undefined;
var renderer: *sdl.SDL_Renderer = undefined;

pub const render_scale = 3;

pub fn init() !void {
    // Initialize SDL2
    sdl.SDL_LogSetAllPriority(sdl.SDL_LOG_PRIORITY_VERBOSE);
    if(sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        sdlPanic();
    }

    std.debug.print("Initialized SDL\n", .{});

    window = sdl.SDL_CreateWindow(
        "Brass Emulator",
        sdl.SDL_WINDOWPOS_UNDEFINED,
        sdl.SDL_WINDOWPOS_UNDEFINED,
        320 * render_scale,
        200 * render_scale,
        sdl.SDL_WINDOW_SHOWN) orelse sdlPanic();

    renderer = sdl.SDL_CreateRenderer(
        window,
        -1,
        sdl.SDL_RENDERER_SOFTWARE | sdl.SDL_RENDERER_PRESENTVSYNC) orelse sdlPanic();

    _ = sdl.SDL_RenderSetScale(renderer, render_scale, render_scale);
}

pub fn deinit() void {
    sdl.SDL_Quit();
    sdl.SDL_DestroyWindow(window);
    sdl.SDL_DestroyRenderer(renderer);
}

pub fn processEvents() void {
    var sdl_event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&sdl_event) != 0) {
        switch (sdl_event.type) {
            sdl.SDL_QUIT => {
                std.debug.print("SDL: asked for exit.\n", .{});
                main.stop();
                break;
            },
            else => {},
        }
    }
}

pub fn getRenderer() *sdl.SDL_Renderer {
    return renderer;
}

pub fn present() void {
    // Swap the buffers, update the screen
    sdl.SDL_RenderPresent(renderer);
}

pub fn delay(delay_time: u8) void {
    sdl.SDL_Delay(delay_time);
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, sdl.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
