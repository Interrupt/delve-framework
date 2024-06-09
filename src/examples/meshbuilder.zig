const std = @import("std");
const delve = @import("delve");
const app = delve.app;

const graphics = delve.platform.graphics;
const math = delve.math;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const test_asset = @embedFile("static/test.gif");
var camera: delve.graphics.camera.Camera = undefined;
var material: graphics.Material = undefined;

var cube1: delve.graphics.mesh.Mesh = undefined;
var cube2: delve.graphics.mesh.Mesh = undefined;
var cube3: delve.graphics.mesh.Mesh = undefined;

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

    const example = delve.modules.Module{
        .name = "meshbuilder_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
    };

    try delve.modules.registerModule(example);
    try delve.module.fps_counter.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Mesh Builder Example" });
}

pub fn on_init() !void {
    var img = delve.images.loadBytes(test_asset) catch {
        delve.debug.log("Error loading image", .{});
        return;
    };
    const tex = graphics.Texture.init(&img);

    // Create a material out of the texture
    material = graphics.Material.init(.{
        .shader = graphics.Shader.initDefault(.{}),
        .texture_0 = tex,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // create our camera
    camera = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 20.0, 5.0, math.Vec3.up);

    // make a cube
    cube1 = delve.graphics.mesh.createCube(math.Vec3.new(0, 0, 0), math.Vec3.new(2, 3, 1), delve.colors.white, material) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    // and another
    cube2 = delve.graphics.mesh.createCube(math.Vec3.new(3, 0, -1), math.Vec3.new(1, 1, 2), delve.colors.green, material) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    // and then a floor
    cube3 = delve.graphics.mesh.createCube(math.Vec3.new(0, -2, 0), math.Vec3.new(12, 0.25, 12), delve.colors.red, material) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    // set a bg color
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_dark);

    // capture mouse
    delve.platform.app.captureMouse(true);
}

pub fn on_tick(delta: f32) void {
    if (delve.platform.input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();

    time += delta;

    camera.runSimpleCamera(8 * delta, 120 * delta, true);
}

pub fn on_draw() void {
    const proj_view_matrix = camera.getProjView();
    var model = math.Mat4.identity;

    const frustum = camera.getViewFrustum();
    if (!frustum.containsPoint(math.Vec3.new(0, 0, 0))) {
        return;
    }

    cube1.draw(proj_view_matrix, model.mul(math.Mat4.rotate(@floatCast(time * 40.0), math.Vec3.new(0, 1, 0))));
    cube2.draw(proj_view_matrix, model);
    cube3.draw(proj_view_matrix, model);
}
