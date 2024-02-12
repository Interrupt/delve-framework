const std = @import("std");
const delve = @import("delve");
const app = delve.app;

// we'll draw some other examples inside of ours
const nested_example_1 = @import("forest.zig").module;
const nested_example_2 = @import("sprite-animation.zig").module;

const graphics = delve.platform.graphics;
const math = delve.math;

const test_asset = @embedFile("static/test.gif");

var camera: delve.graphics.camera.Camera = undefined;
var camera_offscreen: delve.graphics.camera.Camera = undefined;

var material1: graphics.Material = undefined;
var material2: graphics.Material = undefined;
var material3: graphics.Material = undefined;

var cube1: delve.graphics.mesh.Mesh = undefined;
var cube2: delve.graphics.mesh.Mesh = undefined;
var cube3: delve.graphics.mesh.Mesh = undefined;

var time: f64 = 0.0;

var offscreen_pass: graphics.RenderPass = undefined;
var offscreen_pass_2: graphics.RenderPass = undefined;

pub fn main() !void {
    const example = delve.modules.Module{
        .name = "passes_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
    };

    try delve.modules.registerModule(example);
    try delve.module.fps_counter.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Render Passes Example" });
}

pub fn on_init() void {
    var img = delve.images.loadBytes(test_asset) catch {
        delve.debug.log("Error loading image", .{});
        return;
    };
    const tex = graphics.Texture.init(&img);

    // Create our offscreen passes
    offscreen_pass = graphics.RenderPass.init(.{ .width = 1024, .height = 768 });
    offscreen_pass_2 = graphics.RenderPass.init(.{ .width = 640, .height = 480 });

    // Create a material out of the texture
    material1 = graphics.Material.init(.{
        .shader = graphics.Shader.initDefault(.{}),
        .texture_0 = tex,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // Create a material that uses our main offscreen render texture
    material2 = graphics.Material.init(.{
        .shader = graphics.Shader.initDefault(.{}),
        .texture_0 = offscreen_pass.render_texture_color,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // Create a material that uses our secondary offscreen render texture
    material3 = graphics.Material.init(.{
        .shader = graphics.Shader.initDefault(.{}),
        .texture_0 = offscreen_pass_2.render_texture_color,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // create our cameras
    camera = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 200.0, 5.0, math.Vec3.up());
    camera_offscreen = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 200.0, 5.0, math.Vec3.up());

    // make a cube
    cube1 = delve.graphics.mesh.createCube(math.Vec3.new(0, 0, 0), math.Vec3.new(2, 3, 1), delve.colors.white, material1) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    // and another
    cube2 = delve.graphics.mesh.createCube(math.Vec3.new(3, 0, -1), math.Vec3.new(1, 1, 2), delve.colors.white, material3) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    // and then a screen
    cube3 = delve.graphics.mesh.createCube(math.Vec3.new(0, 0, 0), math.Vec3.new(20, 12.0, 0.25), delve.colors.white, material2) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    // set a bg color
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_dark);

    // capture mouse
    delve.platform.app.captureMouse(true);

    // initialize the nested examples too
    if (nested_example_1.init_fn) |init_fn| init_fn();
    if (nested_example_2.init_fn) |init_fn| init_fn();
}

pub fn on_tick(delta: f32) void {
    if (delve.platform.input.isKeyJustPressed(.ESCAPE))
        std.os.exit(0);

    time += delta;

    // do fps camera
    camera.runSimpleCamera(8 * delta, 120 * delta, true);

    // rotate offscreen camera
    camera_offscreen.yaw(delta * 60.0);

    // our secondary nested module needs to tick
    if (nested_example_2.tick_fn) |tick_fn| tick_fn(delta);
}

pub fn on_draw() void {

    // do our secondary pass first
    graphics.beginPass(offscreen_pass_2, delve.colors.tan);
    // render pass for the secondary nested module
    nested_example_2.runFullRenderLifecycle();
    graphics.endPass();

    // begin the offscreen pass
    graphics.beginPass(offscreen_pass, delve.colors.black);

    // draw using the offscreen camera
    var proj_view_matrix = camera_offscreen.getProjView();

    // draw a few cubes inside the offscreen pass
    cube1.draw(proj_view_matrix, math.Mat4.translate(math.Vec3.new(-3, 0, 0)).mul(math.Mat4.rotate(@floatCast(time * 160.0), math.Vec3.new(0, 1, 0))));
    cube2.draw(proj_view_matrix, math.Mat4.identity());

    // render pass for the primary nested module
    nested_example_1.runFullRenderLifecycle();

    // stop drawing to our offscreen pass
    graphics.endPass();

    // use the fps camera
    proj_view_matrix = camera.getProjView();

    // draw the screen cube
    cube3.draw(proj_view_matrix, math.Mat4.translate(math.Vec3.new(0, 0, -20)).mul(math.Mat4.rotate(@floatCast(time * 10.0), math.Vec3.new(0, 1, 0))));

    // reset the clear color back to ours
    graphics.setClearColor(delve.colors.examples_bg_dark);
}
