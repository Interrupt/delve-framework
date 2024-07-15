const std = @import("std");
const delve = @import("delve");
const app = delve.app;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// easy access to some imports
const cam = delve.graphics.camera;
const colors = delve.colors;
const debug = delve.debug;
const graphics = delve.platform.graphics;
const images = delve.images;
const input = delve.platform.input;
const math = delve.math;
const modules = delve.modules;
const skinned_mesh = delve.graphics.skinned_mesh;

// easy access to some types
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Color = colors.Color;

const shader_builtin = delve.shaders.default_skinned;

var time: f32 = 0.0;
var mesh_test: ?skinned_mesh.SkinnedMesh = null;
var camera: cam.Camera = undefined;

const mesh_file = "assets/meshes/CesiumMan.gltf";
const mesh_texture_file = "assets/meshes/CesiumMan.png";

// currently playing animation
var anim_idx: usize = 0;

// This example shows loading and drawing animated meshes

// Web build note: this does not seem to work when built in --release=fast or --release=small

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
    try app.start(app.AppConfig{ .title = "Delve Framework - Skinned Mesh Drawing Example", .sampler_pool_size = 1024 });
}

pub fn registerModule() !void {
    const meshExample = modules.Module{
        .name = "skinned_mesh_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(meshExample);
}

fn on_init() !void {
    debug.log("Skinned mesh example module initializing", .{});

    graphics.setClearColor(colors.examples_bg_light);

    // Make a perspective camera, with a 90 degree FOV
    camera = cam.Camera.initThirdPerson(90.0, 0.01, 150.0, 2.0, Vec3.up);
    camera.position = Vec3.new(0.0, 0.0, 0.0);
    camera.direction = Vec3.new(0.0, 0.0, 1.0);

    // Make our emissive shader from one that is pre-compiled
    const shader = graphics.Shader.initFromBuiltin(.{ .vertex_attributes = skinned_mesh.getSkinnedShaderAttributes() }, shader_builtin);

    if (shader == null) {
        debug.log("Could not get shader", .{});
        return;
    }

    var base_img: images.Image = images.loadFile(mesh_texture_file) catch {
        debug.log("Assets: Error loading image asset: {s}", .{mesh_texture_file});
        return;
    };
    const tex_base = graphics.Texture.init(&base_img);

    // Create a material out of our shader and textures
    const material = delve.platform.graphics.Material.init(.{
        .shader = shader.?,
        .texture_0 = tex_base,
        .texture_1 = delve.platform.graphics.createSolidTexture(0x00000000),

        // use the VS layout that supports sending joints to the shader
        .default_vs_uniform_layout = delve.platform.graphics.DefaultSkinnedMeshVSUniforms,
    });

    // Load our mesh!
    mesh_test = skinned_mesh.SkinnedMesh.initFromFile(delve.mem.getAllocator(), mesh_file, .{ .material = material });

    // start looping the first animation
    mesh_test.?.playAnimation(0, 1.0, 1.0, true);

    // also try to play an animation by name, if it exists!
    mesh_test.?.playAnimationByName("Run", 1.0, 1.0, true);
}

fn on_tick(delta: f32) void {
    // There is a built in fly mode, but you can also just set the position / direction
    camera.runSimpleCamera(4 * delta, 120 * delta, false);

    time += delta * 100;

    mesh_test.?.updateAnimation(delta);

    if (input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();

    if (input.isKeyJustPressed(.SPACE)) {
        if (!mesh_test.?.playing_animation.playing) {
            const anim_count = mesh_test.?.getAnimationsCount();
            mesh_test.?.playAnimation(@mod(anim_idx, anim_count), 1.0, 1.0, true);
        } else {
            mesh_test.?.stopAnimation(1.0);
        }
    }
}

fn on_draw() void {
    // Exit early if we have no mesh loaded
    if (mesh_test == null)
        return;

    const proj_view_matrix = camera.getProjView();

    var model = Mat4.translate(Vec3.new(0.0, -0.75, 0.0));
    model = model.mul(Mat4.rotate(-90, Vec3.new(1.0, 0.0, 0.0)));

    mesh_test.?.draw(proj_view_matrix, model);
}

fn on_cleanup() !void {
    debug.log("Skinned mesh example module cleaning up", .{});

    if (mesh_test == null)
        return;

    mesh_test.?.deinit();
}
