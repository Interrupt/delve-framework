const std = @import("std");
const debug = @import("../debug.zig");
const lua = @import("../scripting/lua.zig");
const gfx = @import("graphics.zig");
const input = @import("input.zig");
const gfx_3d = @import("../graphics/3d.zig");
const batcher = @import("../graphics/batcher.zig");

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;

const Allocator = std.mem.Allocator;

var app_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var app_allocator = app_gpa.allocator();

// Test some stuff
var test_batch: batcher.Batcher = undefined;

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

    test_batch = batcher.Batcher.init() catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };
}

export fn sokol_cleanup() void {
    gfx.deinit();
    sg.shutdown();
}

var tick: u64 = 0;
export fn sokol_frame() void {
    tick += 1;

    lua.callFunction("_update") catch {
        debug.showErrorScreen("Fatal error!");
    };

    gfx.startFrame();

    lua.callFunction("_draw") catch {
        debug.showErrorScreen("Fatal error!");
    };

    // Exercise the batcher. Move this to Lua!
    test_batch.reset();
    for(0 .. 10000) |i| {
        const f_i = @as(f32, @floatFromInt(i));
        const x_pos = std.math.sin(@as(f32, @floatFromInt(tick * i)) * 0.0001) * (1.0 + (f_i * 0.05));
        const y_pos = std.math.cos(@as(f32, @floatFromInt(tick * i)) * 0.0001) * (0.5 + (f_i * 0.05));

        if(@mod(i, 2) != 0) {
            test_batch.addRectangle(x_pos, y_pos, f_i * -0.1, 0.5, 0.5, batcher.TextureRegion.default(), 0xFFFFFFFF);
        } else {
            test_batch.addTriangle(-x_pos, y_pos, f_i * -0.1, 0.5, 0.5, batcher.TextureRegion.default(), 0xFFFFFFFF);
        }
    }
    test_batch.apply();
    test_batch.draw();

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
        .width = 640,
        .height = 480,
        .icon = .{
            .sokol_default = true,
        },
        .window_title = "DelveEngine",
        .logger = .{
            .func = slog.func,
        },
        .win32_console_attach = true,
    });
}
