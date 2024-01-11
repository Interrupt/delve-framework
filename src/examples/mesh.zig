const std = @import("std");
const assets = @import("../api/assets.zig");
const batcher = @import("../graphics/batcher.zig");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const images = @import("../images.zig");
const input = @import("../platform/input.zig");
const math = @import("../math.zig");
const modules = @import("../modules.zig");

const mesh = @import("../graphics/mesh.zig");
const emissive_shader_builtin = @import("../graphics/shaders/emissive.glsl.zig");

var time: f32 = 0.0;
var mesh_test: ?mesh.Mesh = null;

// -- This module exercises loading and drawing a mesh --

pub fn registerModule() !void {
    const meshExample = modules.Module {
        .name = "mesh_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(meshExample);
}

fn on_init() void {
    debug.log("Mesh example module initializing", .{});

    const base_texture_file = "meshes/SciFiHelmet_BaseColor_512.png";
    var base_img: images.Image = images.loadFile(base_texture_file) catch {
        debug.log("Assets: Error loading image asset: {s}", .{base_texture_file});
        return;
    };

    const emissive_texture_file = "meshes/SciFiHelmet_Emissive_512.png";
    var emissive_img: images.Image = images.loadFile(emissive_texture_file) catch {
        debug.log("Assets: Error loading image asset: {s}", .{emissive_texture_file});
        return;
    };

    const tex_base = graphics.Texture.init(&base_img);
    const tex_emissive = graphics.Texture.init(&emissive_img);

    const shader = graphics.Shader.initFromBuiltin(.{}, emissive_shader_builtin);
    if(shader == null) {
        debug.log("Could not get emissive shader", .{});
        return;
    }

    const material = graphics.Material.init(.{
        .texture_0 = tex_base,
        .texture_1 = tex_emissive,
        .shader = shader.?,
    });

    mesh_test = mesh.Mesh.initFromFile("meshes/SciFiHelmet.gltf", .{.material = material});
}

fn on_tick(tick: u64) void {
    time = @floatFromInt(tick);
}

fn on_draw() void {
    // draw the test mesh
    if(mesh_test == null)
        return;

    var view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 6.0 }, math.Vec3.zero(), math.Vec3.up());
    var model = math.Mat4.translate(.{ .x = 2.0, .y = 0.0, .z = 0.0});
    model = model.mul(math.Mat4.rotate(time * 0.6, .{ .x = 0.0, .y = 1.0, .z = 0.0 }));

    graphics.setProjectionPerspective(60.0, 0.01, 50.0);
    graphics.setView(view, model);

    const sin_val = std.math.sin(time * 0.006) + 0.5;
    const params = graphics.ShaderParams{.draw_color = [_]f32{sin_val, sin_val, sin_val, 1.0}};
    mesh_test.?.material.setParams(params);

    mesh_test.?.draw();
}

fn on_cleanup() void {
    debug.log("Mesh example module cleaning up", .{});

    if(mesh_test == null)
        return;

    mesh_test.?.deinit();
}
