const std = @import("std");
const delve = @import("delve");
const app = delve.app;

const graphics = delve.platform.graphics;
const math = delve.math;
const RndGen = std.rand.DefaultPrng;

const test_asset = @embedFile("static/test.gif");
var camera: delve.graphics.camera.Camera = undefined;
var material: graphics.Material = undefined;

var cube1: delve.graphics.mesh.Mesh = undefined;
var cube2: delve.graphics.mesh.Mesh = undefined;
var cube3: delve.graphics.mesh.Mesh = undefined;

var time: f64 = 0.0;

pub fn main() !void {
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

pub fn on_init() void {
    const emissive_texture_file = "meshes/SciFiHelmet_Emissive_512.png";
    var emissive_img = delve.images.loadBytes(test_asset) catch {
        delve.debug.log("Assets: Error loading image asset: {s}", .{emissive_texture_file});
        return;
    };
    const tex = graphics.Texture.init(&emissive_img);

    // Create a material out of the texture
    material = graphics.Material.init(.{
        .shader = graphics.Shader.initDefault(.{}),
        .texture_0 = tex,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // create a camera
    camera = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 200.0, 5.0, math.Vec3.up());

    // make some cubes
    cube1 = delve.graphics.mesh.createCube(math.Vec3.new(0,0,0), math.Vec3.new(2,3,1), delve.colors.white, material) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    cube2 = delve.graphics.mesh.createCube(math.Vec3.new(3,0,-1), math.Vec3.new(1,1,2), delve.colors.green, material) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    cube3 = delve.graphics.mesh.createCube(math.Vec3.new(0,-2,0), math.Vec3.new(12,0.25,12), delve.colors.red, material) catch {
        delve.debug.log("Could not create cube!", .{});
        return;
    };

    // set a bg color
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_dark);
}

pub fn on_tick(delta: f32) void {
    if (delve.platform.input.isKeyJustPressed(.ESCAPE))
        std.os.exit(0);

    time += delta;

    camera.runSimpleCamera(4 * delta, 120 * delta, true);
}

pub fn on_draw() void {
    const proj_view_matrix = camera.getProjView();
    var model = math.Mat4.identity();

    // we'll move some stuff randomly
    var rnd = RndGen.init(0);
    var random = rnd.random();

    // stress test things a bit
    for(0..500) |idx| {
        _ = idx;

        // make a random position
        const spread: f32 = 250.0;
        const rand_x = (random.float(f32) * spread) - spread * 0.5;
        const rand_y = (random.float(f32) * spread) - spread * 0.5;
        const rand_z = (random.float(f32) * spread) - spread * 0.5;

        // make a few random rotations
        const rot: f32 = @floatCast(time * ((random.float(f64) * 250.0) - 125.0));
        const rot2: f32 = @floatCast(time * ((random.float(f64) * 250.0) - 125.0));
        const rot3: f32 = @floatCast(time * ((random.float(f64) * 250.0) - 125.0));

        model = math.Mat4.translate(math.Vec3.new(rand_x, rand_y, rand_z)).mul(math.Mat4.rotate(rot, math.Vec3.new(0,1,0)));

        // now draw our scene
        cube1.draw(proj_view_matrix, model.mul(math.Mat4.rotate(rot2, math.Vec3.new(0,1,0))));
        cube2.draw(proj_view_matrix, model.mul(math.Mat4.rotate(rot3, math.Vec3.new(0,1,0))));
        cube3.draw(proj_view_matrix, model);
    }
}
