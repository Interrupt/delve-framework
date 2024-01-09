const std = @import("std");
const app = @import("../app.zig");
const debug = @import("../debug.zig");
const gfx = @import("graphics.zig");
const input = @import("input.zig");
const modules = @import("../modules.zig");

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;

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

    // Now that there is an app and graphics context, we can start the app subsystems
    app.startSubsystems() catch {
        debug.log("Fatal error starting subsystems!\n", .{});
        return;
    };

    // initialize modules first
    modules.initModules();

    // then kick everything off!
    modules.startModules();
}

export fn sokol_cleanup() void {
    modules.stopModules();
    modules.cleanupModules();
    app.stopSubsystems();
    gfx.deinit();
    sg.shutdown();
}

var tick: u64 = 0;
export fn sokol_frame() void {
    tick += 1;

    // tick first
    modules.tickModules(tick);

    // then draw!
    gfx.startFrame();
    modules.drawModules();
    gfx.endFrame();

    // tell modules this frame is done
    modules.postDrawModules();
}

export fn sokol_input(event: ?*const sapp.Event) void {
    const ev = event.?;
    if(ev.type == .MOUSE_DOWN) {
        input.onMouseDown(@intFromEnum(ev.mouse_button));
    } else if(ev.type == .MOUSE_UP) {
        input.onMouseUp(@intFromEnum(ev.mouse_button));
    } else if (ev.type == .MOUSE_MOVE) {
        input.onMouseMoved(ev.mouse_x, ev.mouse_y);
    } else if(ev.type == .KEY_DOWN) {
        input.onKeyDown(@intFromEnum(ev.key_code));
    } else if(ev.type == .KEY_UP) {
        input.onKeyUp(@intFromEnum(ev.key_code));
    } else if(ev.type == .CHAR) {
        input.onKeyChar(ev.char_code);
    }
}

pub fn startMainLoop(config: app.AppConfig) void {
    sapp.run(.{
        .init_cb = sokol_init,
        .frame_cb = sokol_frame,
        .cleanup_cb = sokol_cleanup,
        .event_cb = sokol_input,
        .width = config.width,
        .height = config.height,
        .icon = .{
            .sokol_default = true,
        },
        .window_title = config.title,
        .logger = .{
            .func = slog.func,
        },
        .win32_console_attach = true,
    });
}
