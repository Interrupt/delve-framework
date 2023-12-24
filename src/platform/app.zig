const std = @import("std");
const debug = @import("../debug.zig");
const lua = @import("../scripting/lua.zig");
const gfx = @import("graphics.zig");
const input = @import("input.zig");
const gfx_3d = @import("../graphics/3d.zig");
const modules = @import("../modules.zig");

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;

const Allocator = std.mem.Allocator;

var app_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var app_allocator = app_gpa.allocator();

pub fn init() !void {
    debug.log("App starting", .{});
}

pub fn deinit() void {
    debug.log("App stopping", .{});
}

export fn sokol_init() void {
    debug.log("Sokol app backend initializing", .{});

    sg.setup(.{
        .context = sgapp.context(),
        .logger = .{ .func = slog.func },
        .buffer_pool_size = 256, // default is 128
    });

    debug.log("Sokol setup backend: {}\n", .{sg.queryBackend()});

    gfx.init() catch {
        debug.log("Fatal error initializing graphics backend!\n", .{});
        return;
    };

    // Load and run the main script
    lua.runFile("main.lua") catch {
        debug.showErrorScreen("Fatal error during startup!");
        return;
    };

    // Call the init lifecycle function
    lua.callFunction("_init") catch {
        debug.showErrorScreen("Fatal error!");
    };

    modules.initModules();
}

export fn sokol_cleanup() void {
    modules.cleanupModules();
    gfx.deinit();
    sg.shutdown();
}

var tick: u64 = 0;
export fn sokol_frame() void {
    tick += 1;

    modules.tickModules(tick);
    lua.callFunction("_update") catch {
        debug.showErrorScreen("Fatal error!");
    };

    gfx.startFrame();

    modules.drawModules();
    lua.callFunction("_draw") catch {
        debug.showErrorScreen("Fatal error!");
    };

    gfx.endFrame();
}

export fn sokol_input(event: ?*const sapp.Event) void {
    const ev = event.?;
    if (ev.type == .MOUSE_MOVE) {
        input.onMouseMoved(ev.mouse_x, ev.mouse_y);
    } else if(ev.type == .KEY_DOWN) {
        input.onKeyDown(@intFromEnum(ev.key_code));
    } else if(ev.type == .KEY_UP) {
        input.onKeyUp(@intFromEnum(ev.key_code));
    } else if(ev.type == .CHAR) {
        input.onKeyChar(ev.char_code);
    }
}

pub fn startMainLoop() void {
    sapp.run(.{
        .init_cb = sokol_init,
        .frame_cb = sokol_frame,
        .cleanup_cb = sokol_cleanup,
        .event_cb = sokol_input,
        .width = 960,
        .height = 540,
        .icon = .{
            .sokol_default = true,
        },
        .window_title = "Delve Framework",
        .logger = .{
            .func = slog.func,
        },
        .win32_console_attach = true,
    });
}
