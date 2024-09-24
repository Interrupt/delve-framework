const std = @import("std");
const delve = @import("delve");
const app = delve.app;

const batcher = delve.graphics.batcher;
const debug = delve.debug;
const colors = delve.colors;
const images = delve.images;
const graphics = delve.platform.graphics;
const input = delve.platform.input;
const papp = delve.platform.app;
const math = delve.math;
const modules = delve.modules;
const sprites = delve.graphics.sprites;

const Color = colors.Color;
const Vec2 = math.Vec2;
const Rect = delve.spatial.Rect;
const TextureRegion = delve.graphics.sprites.TextureRegion;

const def_shader = delve.shaders.default;

var shader_default: graphics.Shader = undefined;
var sprite_batch: batcher.SpriteBatcher = undefined;

var rect1 = Rect.fromSize(Vec2.new(1, 1)).centered();
var rect2 = Rect.fromSize(Vec2.new(0.75, 0.4)).centered();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// This example shows how to check collision against two rectangles

pub fn main() !void {
    // Pick the allocator to use depending on platform
    const builtin = @import("builtin");
    if (builtin.os.tag == .wasi or builtin.os.tag == .emscripten) {
        // Web builds hack: use the C allocator to avoid OOM errors
        // See https://github.com/ziglang/zig/issues/19072
        try delve.init(std.heap.c_allocator);
    } else {
        // Using the default allocator will let us detect memory leaks
        try delve.init(delve.mem.createDefaultAllocator());
    }

    try registerModule();
    try app.start(app.AppConfig{ .title = "Delve Framework - Collision" });
}

pub fn registerModule() !void {
    const example = modules.Module{
        .name = "rect_collision_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(example);
}

fn on_init() !void {
    debug.log("Collision example module initializing", .{});
    shader_default = try graphics.Shader.initDefault(.{});

    sprite_batch = batcher.SpriteBatcher.init(.{}) catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };

    graphics.setClearColor(colors.examples_bg_light);
}

fn on_tick(deltatime: f32) void {
    _ = deltatime;

    const mouse_pos = input.getMousePosition();
    const app_width: f32 = @floatFromInt(delve.platform.app.getWidth());
    const app_height: f32 = @floatFromInt(delve.platform.app.getHeight());

    const x_pos = ((mouse_pos.x / app_width) - 0.5) * 6.0;
    const y_pos = ((mouse_pos.y / app_height) - 0.5) * -4.0;
    rect2 = rect2.setPosition(Vec2.new(x_pos, y_pos));

    if (input.isKeyJustPressed(.ESCAPE)) {
        papp.exit();
    }
}

fn on_draw() void {
    // clear the batch for this frame
    sprite_batch.reset();

    // make sure we are using the right shader and texture
    sprite_batch.useShader(shader_default);
    sprite_batch.useTexture(graphics.tex_white);

    // add our rectangles
    const color = if (rect1.overlapsRect(rect2)) colors.red else colors.white;
    sprite_batch.addRectangle(rect1, TextureRegion.default(), color);
    sprite_batch.addRectangle(rect2, TextureRegion.default(), color);

    // apply the batch to make it ready to draw!
    sprite_batch.apply();

    // setup our view to draw with
    const projection = graphics.getProjectionPerspective(60, 0.01, 20.0);
    const view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 5.0 }, math.Vec3.zero, math.Vec3.up);

    // draw the sprite batch
    sprite_batch.draw(.{ .view = view, .proj = projection }, math.Mat4.identity);
}

fn on_cleanup() !void {
    debug.log("Collision animation example module cleaning up", .{});
    sprite_batch.deinit();
    shader_default.destroy();
}
