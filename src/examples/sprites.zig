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

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Color = colors.Color;
const Rect = delve.spatial.Rect;

pub const test_asset_1 = @embedFile("static/test.png");
pub const test_asset_2 = @embedFile("static/test2.gif");

var texture_1: graphics.Texture = undefined;
var texture_2: graphics.Texture = undefined;

var shader_opaque: graphics.Shader = undefined;
var shader_blend: graphics.Shader = undefined;

var test_material_1: graphics.Material = undefined;
var test_material_2: graphics.Material = undefined;

var test_batch: batcher.SpriteBatcher = undefined;

const stress_test_count = 10000;

// This example shows how to draw sprites and shapes using the sprite batchers

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
    try app.start(app.AppConfig{ .title = "Delve Framework - Sprite Batch Example" });
}

pub fn registerModule() !void {
    const batcherExample = modules.Module{
        .name = "batcher_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .pre_draw_fn = pre_draw,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(batcherExample);
}

fn on_init() !void {
    debug.log("Batch example module initializing", .{});

    test_batch = batcher.SpriteBatcher.init(.{}) catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };

    // load some images
    var test_image_1 = images.loadBytes(test_asset_1) catch {
        debug.log("Could not load test texture", .{});
        return;
    };
    defer test_image_1.deinit();

    var test_image_2 = images.loadBytes(test_asset_2) catch {
        debug.log("Could not load test texture", .{});
        return;
    };
    defer test_image_2.deinit();

    // make some textures from our images
    texture_1 = graphics.Texture.init(test_image_1);
    texture_2 = graphics.Texture.init(test_image_2);

    // make some shaders for testing
    shader_opaque = try graphics.Shader.initDefault(.{});
    shader_blend = try graphics.Shader.initDefault(.{ .blend_mode = graphics.BlendMode.BLEND });

    // Create some test materials out of our shader and textures
    test_material_1 = try graphics.Material.init(.{
        .shader = shader_opaque,
        .texture_0 = graphics.tex_white,
        .cull_mode = .BACK,
        .blend_mode = .BLEND,
    });

    test_material_2 = try graphics.Material.init(.{
        .shader = shader_opaque,
        .texture_0 = texture_1,
        .cull_mode = .BACK,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    graphics.setClearColor(colors.examples_bg_light);
}

fn on_tick(deltatime: f32) void {
    test_material_2.state.params.texture_pan.x += deltatime;
    test_material_2.state.params.texture_pan.y += 0.5 * deltatime;

    if (input.isKeyJustPressed(.ESCAPE)) {
        papp.exit();
    }
}

var tick: u64 = 0;
var time: f32 = 0;
fn pre_draw() void {
    tick += 1;
    time += (1.0 / 60.0) * 100.0;

    test_batch.reset();
    for (0..stress_test_count) |i| {
        const f_i = @as(f32, @floatFromInt(i));
        const x_pos = std.math.sin((time * f_i) * 0.0001) * (1.0 + (f_i * 0.05));
        const y_pos = std.math.cos((time * f_i) * 0.0001) * (0.5 + (f_i * 0.05));

        if (@mod(i, 3) == 0) {
            test_batch.useTexture(texture_1);
        } else {
            test_batch.useTexture(texture_2);
        }

        if (@mod(i, 5) == 0) {
            test_batch.useShader(shader_blend);
        } else {
            test_batch.useShader(shader_opaque);
        }

        var transform: math.Mat4 = undefined;
        if (@mod(i, 2) != 0) {
            transform = math.Mat4.translate(.{ .x = x_pos, .y = y_pos, .z = f_i * -0.1 });
            transform = transform.mul(math.Mat4.rotate(f_i * 3.0, .{ .x = 1.0, .y = 1.0, .z = 0.0 }));
            test_batch.setTransformMatrix(transform);

            const rect = Rect.fromSize(math.Vec2.new(0.5, 0.5));
            test_batch.addRectangle(rect, sprites.TextureRegion.default(), colors.white);
        } else {
            transform = math.Mat4.translate(.{ .x = -x_pos, .y = y_pos, .z = f_i * -0.1 });
            transform = transform.mul(math.Mat4.rotate(f_i * 3.0, .{ .x = 0.0, .y = -1.0, .z = 0.0 }));
            test_batch.setTransformMatrix(transform);

            test_batch.addTriangle(math.Vec2{ .x = 0, .y = 0 }, math.Vec2{ .x = 0.5, .y = 0.5 }, sprites.TextureRegion.default(), colors.white);
        }
    }

    test_batch.useShader(shader_blend);

    // test a line!
    const line_y_start = std.math.sin(time * 0.01);
    const line_y_end = std.math.cos(time * 0.012);

    test_batch.setTransformMatrix(math.Mat4.identity);
    test_batch.useTexture(graphics.tex_black);
    test_batch.addLine(math.vec2(0, line_y_start), math.vec2(2, line_y_end), 0.05, sprites.TextureRegion.default(), colors.white);

    // test a line rectangle!
    test_batch.useTexture(graphics.tex_white);
    const rect1 = Rect.new(math.vec2(-2.5, 0), math.vec2(2, 0.5));
    test_batch.addLineRectangle(rect1, 0.05, sprites.TextureRegion.default(), colors.black);

    // test using materials as well!
    // test a filled rectangle
    test_batch.useMaterial(test_material_1);
    test_batch.setTransformMatrix(math.Mat4.translate(math.vec3(0, 0, -0.001)));

    test_batch.addRectangle(rect1, sprites.TextureRegion.default(), colors.cyan.mul(Color{ .a = 0.75 }));

    test_batch.useMaterial(test_material_2);
    test_batch.setTransformMatrix(math.Mat4.translate(math.vec3(1, -1, -0.001)));

    const rect3 = Rect.new(math.vec2(-1.0, 0), math.vec2(1, 1));
    test_batch.addRectangle(rect3, sprites.TextureRegion.default(), colors.cyan);

    test_batch.apply();
}

fn on_draw() void {
    // Draw with a 60 degree fov
    const projection = graphics.getProjectionPerspective(60.0, 0.01, 50.0);

    const mouse_pos = input.getMousePosition();
    const view_translate = math.Vec3{ .x = -3.5 + mouse_pos.x * 0.007, .y = 1 + -mouse_pos.y * 0.0075, .z = 0 };

    var view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 6.0 }, math.Vec3.zero, math.Vec3.up);
    view = view.mul(math.Mat4.translate(view_translate));
    view = view.mul(math.Mat4.rotate(25.0, .{ .x = 0.0, .y = 1.0, .z = 0.0 }));

    test_batch.draw(.{ .view = view, .proj = projection }, math.Mat4.identity);
}

fn on_cleanup() !void {
    debug.log("Batch example module cleaning up", .{});
    test_batch.deinit();
    test_material_1.deinit();
    test_material_2.deinit();
    texture_1.destroy();
    texture_2.destroy();
    shader_opaque.destroy();
    shader_blend.destroy();
}
