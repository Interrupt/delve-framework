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

// let our example cycle through some fonts
const example_fonts = [_][]const u8{ "DroidSans", "Tiny5", "CrimsonPro", "AmaticSC", "KodeMono", "Rajdhani", "IBMPlexSerif" };
var cur_font_idx: usize = 0;
var time: f64 = 0.0;

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

    _ = try delve.fonts.loadFont("DroidSans", "assets/fonts/DroidSans.ttf", 1024, 200);
    _ = try delve.fonts.loadFont("Tiny5", "assets/fonts/Tiny5-Regular.ttf", 512, 100);
    _ = try delve.fonts.loadFont("CrimsonPro", "assets/fonts/CrimsonPro-Regular.ttf", 1024, 200);
    _ = try delve.fonts.loadFont("AmaticSC", "assets/fonts/AmaticSC-Regular.ttf", 1024, 200);
    _ = try delve.fonts.loadFont("KodeMono", "assets/fonts/KodeMono-Regular.ttf", 1024, 200);
    _ = try delve.fonts.loadFont("Rajdhani", "assets/fonts/Rajdhani-Regular.ttf", 1024, 200);
    _ = try delve.fonts.loadFont("IBMPlexSerif", "assets/fonts/IBMPlexSerif-Regular.ttf", 1024, 200);
}

fn on_tick(delta: f32) void {
    time += @floatCast(delta);

    if (input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();
}

// Debug function to visualize a font atlas
pub fn debugDrawTexAtlas(font: *delve.fonts.LoadedFont) void {
    const size = 200.0;
    graphics.drawDebugRectangle(font.texture, 120.0, 40.0, size, size, colors.white);
}

fn on_draw() void {
    cur_font_idx = @as(usize, @intFromFloat(time)) % example_fonts.len;

    const font_to_use = example_fonts[cur_font_idx];
    const text_scale: f32 = 0.003;

    // Drawing position of characters, updated as each gets added
    var x_pos: f32 = 0.0;
    var y_pos: f32 = 0.0;

    const message = "This is some text!\nHello World!\n[]'.@%#$<>?;:-=_+'";

    const font_name_string = std.fmt.allocPrintZ(delve.mem.getAllocator(), "Drawing from {s}", .{font_to_use}) catch {
        return;
    };
    defer delve.mem.getAllocator().free(font_name_string);

    // grab the font to use
    const found_font = delve.fonts.getLoadedFont(font_to_use);

    // Add font characters as sprites to our sprite batch
    font_batch.reset();

    if (found_font) |font| {
        delve.fonts.addStringToSpriteBatch(font, &font_batch, font_name_string, &x_pos, &y_pos, text_scale);
        delve.fonts.addStringToSpriteBatch(font, &font_batch, message, &x_pos, &y_pos, text_scale);
    }

    font_batch.apply();

    const projection = graphics.getProjectionPerspective(60.0, 0.01, 50.0);
    const view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 6.0 }, math.Vec3.zero, math.Vec3.up);

    font_batch.draw(projection.mul(view), math.Mat4.translate(.{ .x = -3.25, .y = 1.25, .z = 0.0 }));
}

fn on_cleanup() !void {
    debug.log("Fonts example module cleaning up", .{});
}
