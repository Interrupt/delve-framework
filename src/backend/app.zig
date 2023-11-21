const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;

//const sokol_app = @import("../../3rdparty/sokol-zig/src/sokol/app.zig");
const debug = @import("../debug.zig");

var pass_action: sg.PassAction = .{};

pub fn init() !void {
    debug.log("App starting", .{});

    sg.setup(.{
        .context = sgapp.context(),
        .logger = .{ .func = slog.func },
    });
    pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 1, .g = 1, .b = 0, .a = 1 },
    };

    debug.log("App backend: {}\n", .{sg.queryBackend()});
}

pub fn deinit() void {
    debug.log("App stopping", .{});
}

pub fn cleanup() void {
    sg.shutdown();
}

pub fn frame() void {
    const g = pass_action.colors[0].clear_value.g + 0.01;
    pass_action.colors[0].clear_value.g = if (g > 1.0) 0.0 else g;
    sg.beginDefaultPass(pass_action, sapp.width(), sapp.height());
    sg.endPass();
    sg.commit();
}

pub fn mainloop() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = 640,
        .height = 480,
        .icon = .{
            .sokol_default = true,
        },
        .window_title = "clear.zig",
        .logger = .{
            .func = slog.func,
        },
        .win32_console_attach = true,
    });
}
