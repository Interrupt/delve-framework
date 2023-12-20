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
var test_mesh: gfx_3d.Mesh = undefined;
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
        showErrorScreen("Fatal error during startup!");
        return;
    };

    // Call the init lifecycle function
    lua.callFunction("_init") catch {
        showErrorScreen("Fatal error!");
    };

    test_batch = batcher.Batcher.init() catch {
        showErrorScreen("Fatal error during batch init!");
        return;
    };

    // for(0 .. 5000) |i| {
    //     const f_i = @as(f32, @floatFromInt(i));
    //     if(@mod(i, 2) != 0) {
    //         test_batch.addRectangle(0, f_i * 0.1, f_i * 0.25, 0.25 + 0.25 * f_i , 0.5);
    //     } else {
    //         test_batch.addTriangle(0, f_i * 0.1, f_i * 0.25, 0.25 + 0.25 * f_i , 0.5);
    //     }
    // }
    // test_batch.apply();

    // var verts: []gfx.Vertex = &[_]gfx.Vertex{
    //     .{ .x = 0.0, .y = 1.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 0, .v = 0 },
    //     .{ .x = 1.0, .y = 1.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 6550, .v = 0 },
    //     .{ .x = 1.0, .y = 0.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 6550, .v = 6550},
    //     .{ .x = 0.0, .y = 0.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 0, .v = 6550},
    // };
    // // rectangler indices
    // var indices: []u16 = &[_]u16{ 0, 1, 2, 0, 2, 3 };
    //
    // test_mesh = gfx_3d.createMesh(&verts, &indices);

}

export fn sokol_cleanup() void {
    gfx.deinit();
    sg.shutdown();
}

var tick: u64 = 0;
export fn sokol_frame() void {
    tick += 1;

    lua.callFunction("_update") catch {
        showErrorScreen("Fatal error!");
    };

    gfx.startFrame();

    lua.callFunction("_draw") catch {
        showErrorScreen("Fatal error!");
    };

    test_batch.reset();
    for(0 .. 5000) |i| {
        const f_i = @as(f32, @floatFromInt(i));
        const x_pos = std.math.sin(@as(f32, @floatFromInt(tick * i)) * 0.001) * 1.5;
        const y_pos = std.math.cos(@as(f32, @floatFromInt(tick * i)) * 0.001) * 1.0;

        if(@mod(i, 2) != 0) {
            test_batch.addRectangle(x_pos, y_pos, f_i * 0.1, 0.5, 0.5);
        } else {
            test_batch.addTriangle(-x_pos, y_pos, f_i * 0.1, 0.5, 0.5);
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

pub fn showErrorScreen(error_header: [:0]const u8) void {
    // Simple lua function to make the draw function draw an error screen
    const error_screen_lua =
        \\ _draw = function()
        \\ require('draw').clear(1)
        \\ require('text').draw("{s}", 8, 8, 0)
        \\ require('text').draw_wrapped([[{s}]], 8, 24, 264, 0)
        \\ end
        \\
        \\ _update = function() end
    ;

    // Assume that the last log line is what exploded!
    const log_history = debug.getLogHistory();
    var error_desc: [:0]const u8 = undefined;
    if (log_history.last()) |last_log| {
        error_desc = last_log.data;
    } else {
        error_desc = "Something bad happened!";
    }

    // Only use until the first newline
    var error_desc_splits = std.mem.split(u8, error_desc, "\n");
    var first_split = error_desc_splits.first();

    const written = std.fmt.allocPrintZ(app_allocator, error_screen_lua, .{ error_header, first_split }) catch {
        std.debug.print("Error allocating to show error screen?\n", .{});
        return;
    };
    defer app_allocator.free(written);

    // Reset to an error palette!
    // palette.raw[0] = 0x22;
    // palette.raw[1] = 0x00;
    // palette.raw[2] = 0x00;
    // palette.raw[3] = 0xFF;
    //
    // palette.raw[4] = 0x99;
    // palette.raw[5] = 0x00;
    // palette.raw[6] = 0x00;
    // palette.raw[7] = 0xFF;

    std.debug.print("Showing error screen: {s}\n", .{error_header});
    lua.runLine(written) catch {
        std.debug.print("Error running lua to show error screen?\n", .{});
    };
}
