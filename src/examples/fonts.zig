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
    graphics.setClearColor(colors.black);

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
    // const size = 200.0;
    // graphics.drawDebugRectangle(texture, 120.0, 40.0, size, size, colors.white);

    font_batch.reset();
    font_batch.useTexture(texture);

    var x_pos: f32 = -1600.0;
    var y_pos: f32 = -400.0;

    const message = "This is some text!\nDrawing from DroidSans.ttf\nHello World [] '.@$'";

    const text_scale: f32 = mouse_pos.y * 0.00002;

    for (message) |char| {
        if (char == '\n') {
            x_pos = -1600.0;
            y_pos += 200;
            continue;
        }

        const char_quad_t = delve.fonts.getCharQuad("DroidSans", char - 32, &x_pos, &y_pos);
        font_batch.addRectangle(char_quad_t.rect.scale(text_scale), char_quad_t.tex_region, colors.white);
    }

    font_batch.apply();

    const projection = graphics.getProjectionPerspective(60.0, 0.01, 50.0);
    const view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 6.0 }, math.Vec3.zero, math.Vec3.up);
    font_batch.draw(projection.mul(view), math.Mat4.identity);
}

fn on_cleanup() !void {
    debug.log("Fonts example module cleaning up", .{});
}
