const std = @import("std");
const delve = @import("delve");
const app = delve.app;

const debug = delve.debug;
const graphics = delve.platform.graphics;
const colors = delve.colors;
const input = delve.platform.input;
const math = delve.math;
const modules = delve.modules;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var font_batch: delve.graphics.batcher.SpriteBatcher = undefined;

pub fn main() !void {
    // Pick the allocator to use depending on platform
    const builtin = @import("builtin");
    if (builtin.os.tag == .wasi or builtin.os.tag == .emscripten) {
        // Web builds hack: use the C allocator to avoid OOM errors
        // See https://github.com/ziglang/zig/issues/19072
        try delve.init(std.heap.c_allocator);
    } else {
        try delve.init(gpa.allocator());
    }

    try registerModule();
    try app.start(app.AppConfig{ .title = "Delve Framework - Fonts Example" });
}

pub fn registerModule() !void {
    const fontsExample = modules.Module{
        .name = "fonts_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(fontsExample);
}

fn on_init() !void {
    debug.log("Fonts example module initializing", .{});
    graphics.setClearColor(colors.examples_bg_dark);

    font_batch = delve.graphics.batcher.SpriteBatcher.init(.{}) catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };
}

fn on_tick(delta: f32) void {
    _ = delta;
    if (input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();
}

fn on_draw() void {
    const texture = delve.fonts.default_font_tex;
    const mouse_pos = input.getMousePosition();

    // const size = 50.0 + (400.0 * mouse_pos.x * 0.008);
    const size = 200.0;

    graphics.drawDebugRectangle(texture, 120.0, 40.0, size, size, colors.white);

    const info = delve.fonts.getCharInfo("DroidSans");

    font_batch.reset();
    font_batch.useTexture(texture);

    if (info) |infos| {
        if (mouse_pos.y > 0) {
            const to_check: usize = @intCast(@abs(@as(usize, @intFromFloat(mouse_pos.y))) / 5);
            if (to_check < infos.len) {
                const ci = infos[to_check];
                // debug.log("{}", .{ci});

                const x_width: f32 = @floatFromInt(ci.x1 - ci.x0);
                const y_width: f32 = @floatFromInt(ci.y1 - ci.y0);

                const char_size: f32 = 0.01;
                const rect = delve.spatial.Rect.fromSize(math.Vec2.new(x_width * char_size, y_width * char_size));

                const x0 = @as(f32, @floatFromInt(ci.x0)) / 1024.0;
                const y0 = @as(f32, @floatFromInt(ci.y0)) / 1024.0;
                const x1 = @as(f32, @floatFromInt(ci.x1)) / 1024.0;
                const y1 = @as(f32, @floatFromInt(ci.y1)) / 1024.0;

                const region: delve.graphics.sprites.TextureRegion = .{ .u = x0, .v = y0, .u_2 = x1, .v_2 = y1 };
                font_batch.addRectangle(rect, region, colors.white);
            }
        }
    }

    // const rect = delve.spatial.Rect.fromSize(math.Vec2.new(2.0, 2.0));
    // font_batch.addRectangle(rect, delve.graphics.sprites.TextureRegion.default(), colors.white);
    font_batch.apply();

    const projection = graphics.getProjectionPerspective(60.0, 0.01, 50.0);
    const view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 6.0 }, math.Vec3.zero, math.Vec3.up);
    font_batch.draw(projection.mul(view), math.Mat4.identity);
}

fn on_cleanup() !void {
    debug.log("Fonts example module cleaning up", .{});
}
