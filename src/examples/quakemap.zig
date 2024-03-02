const std = @import("std");
const delve = @import("delve");
const app = delve.app;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const graphics = delve.platform.graphics;
const math = delve.math;

var camera: delve.graphics.camera.Camera = undefined;
var material: graphics.Material = undefined;

var map_meshes: std.ArrayList(delve.graphics.mesh.Mesh) = undefined;

var time: f64 = 0.0;

pub fn main() !void {
    const example = delve.modules.Module{
        .name = "quakemap_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
    };

    try delve.modules.registerModule(example);
    try delve.module.fps_counter.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Quake Map Example" });
}

pub fn on_init() !void {
    const tex = graphics.createDebugTexture();

    const test_map_file =
        \\// Game: Generic
        \\// Format: Standard
        \\// entity 0
        \\{
        \\"classname" "worldspawn"
        \\// brush 0
        \\{
        \\( -64 -64 -16 ) ( -64 -63 -16 ) ( -64 -64 -15 ) __TB_empty 0 0 0 1 1
        \\( -64 -64 -16 ) ( -64 -64 -15 ) ( -63 -64 -16 ) __TB_empty 0 0 0 1 1
        \\( -64 -64 -16 ) ( -63 -64 -16 ) ( -64 -63 -16 ) __TB_empty 0 0 0 1 1
        \\( 64 64 16 ) ( 64 65 16 ) ( 65 64 16 ) __TB_empty 0 0 0 1 1
        \\( 64 64 16 ) ( 65 64 16 ) ( 64 64 17 ) __TB_empty 0 0 0 1 1
        \\( 64 64 16 ) ( 64 64 17 ) ( 64 65 16 ) __TB_empty 0 0 0 1 1
        \\}
        \\// brush 1
        \\{
        \\( -64 32 16 ) ( -64 33 16 ) ( -64 32 17 ) __TB_empty 0 0 0 1 1
        \\( -64 32 16 ) ( -64 32 17 ) ( -63 32 16 ) __TB_empty 0 0 0 1 1
        \\( -64 32 16 ) ( -63 32 16 ) ( -64 33 16 ) __TB_empty 0 0 0 1 1
        \\( 64 64 96 ) ( 64 65 96 ) ( 65 64 96 ) __TB_empty 16 0 0 1 1
        \\( 64 64 32 ) ( 65 64 32 ) ( 64 64 33 ) __TB_empty 0 0 0 1 1
        \\( 64 64 32 ) ( 64 64 33 ) ( 64 65 32 ) __TB_empty 0 0 0 1 1
        \\}
        \\// brush 2
        \\{
        \\( -176 32 80 ) ( -176 33 80 ) ( -176 32 81 ) __TB_empty 0 0 0 1 1
        \\( -176 32 80 ) ( -176 32 81 ) ( -175 32 80 ) __TB_empty 0 0 0 1 1
        \\( -176 32 80 ) ( -175 32 80 ) ( -176 33 80 ) __TB_empty 0 0 0 1 1
        \\( -64 64 96 ) ( -64 65 96 ) ( -63 64 96 ) __TB_empty 0 0 0 1 1
        \\( -64 64 96 ) ( -63 64 96 ) ( -64 64 97 ) __TB_empty 0 0 0 1 1
        \\( -64 64 96 ) ( -64 64 97 ) ( -64 65 96 ) __TB_empty 0 0 0 1 1
        \\}
        \\// brush 3
        \\{
        \\( -176 32 96 ) ( -176 33 96 ) ( -176 32 97 ) __TB_empty 0 0 0 1 1
        \\( -176 32 96 ) ( -176 32 97 ) ( -175 32 96 ) __TB_empty 0 0 0 1 1
        \\( -176 32 96 ) ( -175 32 96 ) ( -176 33 96 ) __TB_empty 0 0 0 1 1
        \\( -144 64 192 ) ( -144 65 192 ) ( -143 64 192 ) __TB_empty 0 0 0 1 1
        \\( -144 64 112 ) ( -143 64 112 ) ( -144 64 113 ) __TB_empty 0 0 0 1 1
        \\( -144 64 112 ) ( -144 64 113 ) ( -144 65 112 ) __TB_empty 0 0 0 1 1
        \\}
        \\// brush 4
        \\{
        \\( -144 32 176 ) ( -144 33 176 ) ( -144 32 177 ) __TB_empty 0 0 0 1 1
        \\( -144 32 176 ) ( -144 32 177 ) ( -143 32 176 ) __TB_empty 0 0 0 1 1
        \\( -144 32 176 ) ( -143 32 176 ) ( -144 33 176 ) __TB_empty 0 0 0 1 1
        \\( -112 48 192 ) ( -112 49 192 ) ( -111 48 192 ) __TB_empty 0 0 0 1 1
        \\( -112 48 192 ) ( -111 48 192 ) ( -112 48 193 ) __TB_empty 0 0 0 1 1
        \\( 0 48 192 ) ( 0 48 193 ) ( 0 49 192 ) __TB_empty 0 0 0 1 1
        \\}
        \\// brush 5
        \\{
        \\( 0 32 128 ) ( 0 48 128 ) ( -32 48 176 ) __TB_empty 0 0 0 1 1
        \\( 0 32 176 ) ( 16 32 128 ) ( 0 32 128 ) __TB_empty 0 0 0 1 1
        \\( 16 32 128 ) ( 16 48 128 ) ( 0 48 128 ) __TB_empty 0 0 0 1 1
        \\( -32 48 176 ) ( 0 48 176 ) ( 0 32 176 ) __TB_empty 0 0 0 1 1
        \\( 0 48 128 ) ( 16 48 128 ) ( 0 48 176 ) __TB_empty 0 0 0 1 1
        \\( 0 48 176 ) ( 16 48 128 ) ( 16 32 128 ) __TB_empty 0 0 0 1 1
        \\}
        \\// brush 6
        \\{
        \\( -144 64 112 ) ( -144 32 112 ) ( -144 32 96 ) __TB_empty 0 0 0 1 1
        \\( -128 32 112 ) ( -112 32 96 ) ( -144 32 96 ) __TB_empty 0 0 0 1 1
        \\( -112 32 96 ) ( -112 64 96 ) ( -144 64 96 ) __TB_empty 0 0 0 1 1
        \\( -144 64 112 ) ( -128 64 112 ) ( -128 32 112 ) __TB_empty 0 0 0 1 1
        \\( -144 64 96 ) ( -112 64 96 ) ( -128 64 112 ) __TB_empty 0 0 0 1 1
        \\( -128 64 112 ) ( -112 64 96 ) ( -112 32 96 ) __TB_empty 28.800003 -25.600002 0 1 1
        \\}
        \\// brush 7
        \\{
        \\( -64 32 80 ) ( -64 0 80 ) ( -64 -48 16 ) __TB_empty 0 0 0 1 1
        \\( -64 0 80 ) ( -32 0 80 ) ( -32 -48 16 ) __TB_empty 0 0 0 1 1
        \\( -32 -48 16 ) ( -32 32 16 ) ( -64 32 16 ) __TB_empty 0 0 0 1 1
        \\( -64 32 80 ) ( -32 32 80 ) ( -32 0 80 ) __TB_empty 0 0 0 1 1
        \\( -32 32 16 ) ( -32 32 80 ) ( -64 32 80 ) __TB_empty 0 0 0 1 1
        \\( -32 0 80 ) ( -32 32 80 ) ( -32 32 16 ) __TB_empty 0 0 0 1 1
        \\}
        \\}
    ;

    var allocator = gpa.allocator();
    var err: delve.utils.quakemap.ErrorInfo = undefined;
    const quake_map = delve.utils.quakemap.QuakeMap.read(allocator, test_map_file, &err) catch {
        delve.debug.log("Could not read Quake map!", .{});
        return;
    };

    // Create a material out of the texture
    material = graphics.Material.init(.{
        .shader = graphics.Shader.initDefault(.{}),
        .texture_0 = tex,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // create our camera
    camera = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 512, 25.0, math.Vec3.up);

    const map_transform = delve.math.Mat4.scale(delve.math.Vec3.new(0.1, 0.1, 0.1)).mul(delve.math.Mat4.rotate(-90, delve.math.Vec3.x_axis));

    // make a cube
    map_meshes = quake_map.buildMeshes(allocator, map_transform, std.StringHashMap(delve.platform.graphics.Material).init(allocator), material) catch {
        delve.debug.log("Could not create Quake map meshes!", .{});
        return;
    };

    // set a bg color
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_light);

    // capture mouse
    // delve.platform.app.captureMouse(true);
}

pub fn on_tick(delta: f32) void {
    if (delve.platform.input.isKeyJustPressed(.ESCAPE))
        std.os.exit(0);

    time += delta;

    camera.runSimpleCamera(8 * delta, 60 * delta, false);
}

pub fn on_draw() void {
    const proj_view_matrix = camera.getProjView();
    var model = math.Mat4.identity;

    for (0..map_meshes.items.len) |idx| {
        map_meshes.items[idx].draw(proj_view_matrix, model);
    }
}
