const std = @import("std");
const delve = @import("delve");
const app = delve.app;

// we'll draw some other examples inside of ours
const nested_example_1 = @import("forest.zig").module;
const nested_example_2 = @import("sprite-animation.zig").module;

const graphics = delve.platform.graphics;
const math = delve.math;

const test_asset = @embedFile("static/test.gif");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var camera: delve.graphics.camera.Camera = undefined;
var camera_offscreen: delve.graphics.camera.Camera = undefined;

var shader: delve.platform.graphics.Shader = undefined;
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
        .pre_draw_fn = pre_draw,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

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

    try delve.modules.registerModule(example);
    try delve.module.fps_counter.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Render Passes Example" });
}

pub fn on_init() !void {
    var img = delve.images.loadBytes(test_asset) catch {
        delve.debug.log("Error loading image", .{});
        return;
    };
    defer img.deinit();
    const tex = graphics.Texture.init(img);

    // Create our offscreen passes
    offscreen_pass = graphics.RenderPass.init(.{ .width = 1024, .height = 768 });
    offscreen_pass_2 = graphics.RenderPass.init(.{ .width = 640, .height = 480 });

    shader = try delve.platform.graphics.Shader.initFromBuiltin(.{ .vertex_attributes = delve.graphics.mesh.getShaderAttributes() }, delve.shaders.default_mesh);

    // Create a material out of the texture
    material1 = try graphics.Material.init(.{
        .shader = shader,
        .texture_0 = tex,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // Create a material that uses our main offscreen render texture
    material2 = try graphics.Material.init(.{
        .shader = shader,
        .texture_0 = offscreen_pass.render_texture_color,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // Create a material that uses our secondary offscreen render texture
    material3 = try graphics.Material.init(.{
        .shader = shader,
        .texture_0 = offscreen_pass_2.render_texture_color,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // create our cameras
    camera = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 200.0, 5.0, math.Vec3.up);
    camera_offscreen = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 200.0, 5.0, math.Vec3.up);

    // Need to flip the textures when drawing an offscreen rendered buffer in OpenGL!
    // Could also use `@glsl_options flip_vert_y` in the shader that actually draws the offscreen textures on the mesh
    const backend = delve.platform.graphics.getBackend();
    const is_opengl = (backend == .GLCORE or backend == .GLES3);
    const flip_mod: math.Vec3 = if (!is_opengl) math.Vec3.new(1, 1, 1) else math.Vec3.new(1, -1, 1);

    // make a cube
    cube1 = delve.graphics.mesh.createCube(math.Vec3.new(0, 0, 0), math.Vec3.new(2, 3, 1), delve.colors.white, material1) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    // and another
    cube2 = delve.graphics.mesh.createCube(math.Vec3.new(3, 0, -1), math.Vec3.new(1, 1, 2).mul(flip_mod), delve.colors.white, material3) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    // and then a screen
    cube3 = delve.graphics.mesh.createCube(math.Vec3.new(0, 0, 0), math.Vec3.new(20, 12.0, 0.25).mul(flip_mod), delve.colors.white, material2) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    // set a bg color
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_dark);

    // capture mouse
    delve.platform.app.captureMouse(true);

    // initialize the nested examples too
    if (nested_example_1.init_fn) |init_fn| try init_fn();
    if (nested_example_2.init_fn) |init_fn| try init_fn();
}

pub fn on_tick(delta: f32) void {
    if (delve.platform.input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();

    time += delta;

    // do fps camera
    camera.runSimpleCamera(8 * delta, 120 * delta, true);

    // rotate offscreen camera
    camera_offscreen.yaw(delta * 60.0);

    // our secondary nested module needs to tick
    if (nested_example_2.tick_fn) |tick_fn| tick_fn(delta);
}

pub fn pre_draw() void {
    // Note: offscreen passes have to happen outside of the main draw lifecycle function, pre_draw would be the best.
    // This is because only one pass can be active at any time, including the default screen pass.

    // Render the secondary module to an offscreen pass first
    graphics.beginPass(offscreen_pass_2, delve.colors.tan);
    nested_example_2.runFullRenderLifecycle();
    graphics.endPass();

    // Now render out the main offscreen pass that also includes the secondary
    const sky_color = delve.colors.Color.newBytes(160, 203, 218, 255);
    graphics.beginPass(offscreen_pass, sky_color);

    // draw using the offscreen camera
    const offscreen_view_mats = camera_offscreen.update();

    // draw a few cubes inside the offscreen pass
    const translate = math.Mat4.translate(math.Vec3.new(-3, 0, 0));
    const rotate = math.Mat4.rotate(@floatCast(time * 160.0), math.Vec3.y_axis);
    cube1.draw(offscreen_view_mats, translate.mul(rotate));
    cube2.draw(offscreen_view_mats, math.Mat4.identity);

    // render pass for the primary nested module
    nested_example_1.runFullRenderLifecycle();

    // stop drawing to our offscreen pass
    graphics.endPass();
}

pub fn on_draw() void {
    // use the fps camera
    const view_mats = camera.update();

    // draw the screen cube
    cube3.draw(view_mats, math.Mat4.translate(math.Vec3.new(0, 0, -20)).mul(math.Mat4.rotate(@floatCast(time * 10.0), math.Vec3.new(0, 1, 0))));

    // reset the clear color back to ours
    graphics.setClearColor(delve.colors.examples_bg_dark);
}

pub fn on_cleanup() !void {
    offscreen_pass.destroy();
    offscreen_pass_2.destroy();
    shader.destroy();
    material1.deinit();
    material2.deinit();
    material3.deinit();
    cube1.deinit();
    cube2.deinit();
    cube3.deinit();

    // cleanup the nested examples too
    if (nested_example_1.cleanup_fn) |cleanup_fn| try cleanup_fn();
    if (nested_example_2.cleanup_fn) |cleanup_fn| try cleanup_fn();
}
