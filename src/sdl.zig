const std = @import("std");
const main = @import("main.zig");
const debug = @import("debug.zig");

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

    debug.log("Initialized SDL\n", .{});

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

        // Hijack input when the console is visible
        if(debug.isConsoleVisible()) {
            if(debug.handleSDLInputEvent(sdl_event))
                continue;
        }

        switch (sdl_event.type) {
            sdl.SDL_QUIT => {
                debug.log("SDL: asked for exit.\n", .{});
                main.stop();
                break;
            },
            sdl.SDL_KEYDOWN => {
                // Toggle console on tilde
                if(sdl_event.key.keysym.sym == sdl.SDLK_BACKQUOTE) {
                    if(sdl.SDL_GetModState() & sdl.KMOD_SHIFT == 1)
                        debug.setConsoleVisible(true);
                }
            },
            sdl.SDL_KEYUP => {
            },
            sdl.SDL_TEXTINPUT => {
            },
            sdl.SDL_TEXTEDITING => {
                debug.log("SDL: text editing started.\n", .{});
            },
            else => {},
        }
    }
}

pub fn getRenderer() *sdl.SDL_Renderer {
    return renderer;
}

pub fn getWindow() *sdl.SDL_Window {
    return window;
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
