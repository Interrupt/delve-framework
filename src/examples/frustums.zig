const std = @import("std");
const delve = @import("delve");
const app = delve.app;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var primary_camera: delve.graphics.camera.Camera = undefined;
var secondary_camera: delve.graphics.camera.Camera = undefined;

var shader: delve.platform.graphics.Shader = undefined;

var material_frustum: delve.platform.graphics.Material = undefined;
var material_cube: delve.platform.graphics.Material = undefined;
var material_highlight: delve.platform.graphics.Material = undefined;

var frustum_mesh: delve.graphics.mesh.Mesh = undefined;
var cube_mesh: delve.graphics.mesh.Mesh = undefined;

var time: f32 = 0.0;

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

    const example = delve.modules.Module{
        .name = "frustums_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try delve.modules.registerModule(example);
    try delve.module.fps_counter.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Frustums Example" });
}

pub fn on_init() !void {
    shader = try delve.platform.graphics.Shader.initFromBuiltin(.{ .vertex_attributes = delve.graphics.mesh.getShaderAttributes() }, delve.shaders.default_mesh);

    // Create some materials
    material_frustum = try delve.platform.graphics.Material.init(.{
        .shader = shader,
        .texture_0 = delve.platform.graphics.createSolidTexture(0x66FFFFFF),
        .cull_mode = .NONE,
        .depth_write_enabled = false,
        .blend_mode = .BLEND,
    });

    material_cube = try delve.platform.graphics.Material.init(.{
        .shader = shader,
        .texture_0 = delve.platform.graphics.tex_white,
    });

    material_highlight = try delve.platform.graphics.Material.init(.{
        .shader = shader,
        .texture_0 = delve.platform.graphics.createSolidTexture(0xFF0000CC),
    });

    // create our two cameras - one for the real camera, and another just to get a smaller frustum from
    primary_camera = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 100.0, 5.0, delve.math.Vec3.up);
    secondary_camera = delve.graphics.camera.Camera.initThirdPerson(30.0, 8, 40.0, 5.0, delve.math.Vec3.up);

    // set initial camera position
    primary_camera.position = delve.math.Vec3.new(0, 30, 32);
    primary_camera.pitch_angle = -50.0;

    // create the two meshes we'll use - a frustum prism, and a cube
    frustum_mesh = createFrustumMesh() catch {
        delve.debug.fatal("Could not create frustum mesh!", .{});
        return;
    };

    cube_mesh = delve.graphics.mesh.createCube(delve.math.Vec3.new(0, 0, 0), delve.math.Vec3.new(1, 1, 1), delve.colors.white, material_cube) catch {
        delve.debug.fatal("Could not create cube mesh!", .{});
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

    primary_camera.runSimpleCamera(8 * delta, 120 * delta, true);
    secondary_camera.setYaw(time * 50.0);
}

pub fn on_draw() void {
    const view_mats = primary_camera.update();
    const frustum_model_matrix = delve.math.Mat4.rotate(secondary_camera.yaw_angle, delve.math.Vec3.up);

    for (0..10) |x| {
        for (0..10) |z| {
            const cube_pos = delve.math.Vec3.new(@floatFromInt(x), 0, @floatFromInt(z)).scale(5.0).sub(delve.math.Vec3.new(25, 0, 25));
            const cube_model_matrix = delve.math.Mat4.translate(cube_pos);

            const frustum = secondary_camera.getViewFrustum();
            const bounds = cube_mesh.bounds.translate(cube_pos);

            if (frustum.containsBoundingBox(bounds)) {
                cube_mesh.drawWithMaterial(material_highlight, view_mats, cube_model_matrix);
            } else {
                cube_mesh.draw(view_mats, cube_model_matrix);
            }
        }
    }

    frustum_mesh.draw(view_mats, frustum_model_matrix);
}

pub fn on_cleanup() !void {
    frustum_mesh.deinit();
    material_highlight.deinit();
    material_cube.deinit();
    material_frustum.deinit();
    shader.destroy();
}

pub fn createFrustumMesh() !delve.graphics.mesh.Mesh {
    var builder = delve.graphics.mesh.MeshBuilder.init(delve.mem.getAllocator());
    defer builder.deinit();

    try builder.addFrustum(secondary_camera.getViewFrustum(), delve.math.Mat4.identity, delve.colors.cyan);

    return builder.buildMesh(material_frustum);
}
