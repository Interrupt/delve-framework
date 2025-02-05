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

var material: delve.platform.graphics.Material = undefined;
var mesh_test: skinned_mesh.SkinnedMesh = undefined;
var animation: skinned_mesh.PlayingAnimation = undefined;

var time: f32 = 0.0;
var camera: cam.Camera = undefined;

const mesh_file = "assets/meshes/CesiumMan.gltf";
const mesh_texture_file = "assets/meshes/CesiumMan.png";

// currently playing animation
var anim_idx: usize = 0;

// This example shows loading and drawing animated meshes

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

    // Make our emissive shader from one that is pre-compiled
    const shader = try graphics.Shader.initFromBuiltin(.{ .vertex_attributes = skinned_mesh.getSkinnedShaderAttributes() }, shader_builtin);

    var base_img: images.Image = images.loadFile(mesh_texture_file) catch {
        debug.log("Assets: Error loading image asset: {s}", .{mesh_texture_file});
        return;
    };
    defer base_img.deinit();

    const tex_base = graphics.Texture.init(base_img);

    // Create a material out of our shader and textures
    material = try delve.platform.graphics.Material.init(.{
        .shader = shader,
        .own_shader = true,
        .texture_0 = tex_base,
        .texture_1 = delve.platform.graphics.createSolidTexture(0x00000000),

        // use the VS layout that supports sending joints to the shader
        .default_vs_uniform_layout = delve.platform.graphics.default_skinned_mesh_vs_uniforms,
    });

    // Load our mesh!
    const loaded = skinned_mesh.SkinnedMesh.initFromFile(delve.mem.getAllocator(), mesh_file, .{ .material = material });

    if (loaded == null) {
        debug.fatal("Could not load skinned mesh!", .{});
        return;
    }

    mesh_test = loaded.?;
    animation = try mesh_test.createAnimation(0, 1.0, true);
}

fn on_tick(delta: f32) void {
    // There is a built in fly mode, but you can also just set the position / direction
    camera.runSimpleCamera(4 * delta, 120 * delta, false);

    time += delta * 100;

    mesh_test.updateAnimation(&animation, delta);

    if (input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();

    // Cycle through animations with the space key
    if (input.isKeyJustPressed(.SPACE)) {
        if (input.isKeyPressed(.LEFT_SHIFT)) {
            animation.anim_idx -= 1;
        } else {
            animation.anim_idx += 1;
        }

        const anim_count = mesh_test.getAnimationsCount();
        animation.anim_idx = @mod(anim_idx, anim_count);

        // reset the animation lerp state
        animation.reset(true);
        animation.blendIn(1.0, false);
    }

    // blend into an animation with the E key
    if (input.isKeyJustPressed(.E)) {
        animation.blendIn(1.0, true);
    }

    // blend out of an animation with the R key
    if (input.isKeyJustPressed(.R)) {
        animation.blendOut(1.0, true);
    }
}

fn on_draw() void {
    const view_mats = camera.update();

    var model = Mat4.translate(Vec3.new(0.0, -0.75, 0.0));
    model = model.mul(Mat4.rotate(-90, Vec3.new(1.0, 0.0, 0.0)));

    mesh_test.resetAnimation(); // reset back to the default pose
    mesh_test.applyAnimation(&animation, 0.9); // apply an animation to the mesh, with 90% blend

    // show off programmatic animations by looking back and forth
    const neck_bone_name = "Skeleton_neck_joint_1";
    var neck_transform = mesh_test.getBoneTransform(neck_bone_name);
    if (neck_transform) |*nt| {
        const neck_rot_angle = std.math.sin(time * 0.005) * 45;
        const neck_rot_quat = math.Quaternion.fromMat4(math.Mat4.rotate(neck_rot_angle, math.Vec3.new(1.0, 0.0, 0.0)));
        nt.rotation = nt.rotation.mul(neck_rot_quat);
        mesh_test.setBoneTransform(neck_bone_name, nt.*);
    }

    mesh_test.draw(view_mats, model);
}

fn on_cleanup() !void {
    debug.log("Skinned mesh example module cleaning up", .{});

    material.deinit();
    animation.deinit();
    mesh_test.deinit();
}
