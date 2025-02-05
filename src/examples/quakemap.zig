const std = @import("std");
const delve = @import("delve");
const app = delve.app;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const graphics = delve.platform.graphics;
const math = delve.math;

var camera: delve.graphics.camera.Camera = undefined;
var shader: delve.platform.graphics.Shader = undefined;
var fallback_material: graphics.Material = undefined;
var fallback_quake_material: delve.utils.quakemap.QuakeMaterial = undefined;
var materials: std.StringHashMap(delve.utils.quakemap.QuakeMaterial) = undefined;

var quake_map: delve.utils.quakemap.QuakeMap = undefined;
var map_meshes: std.ArrayList(delve.graphics.mesh.Mesh) = undefined;
var entity_meshes: std.ArrayList(delve.graphics.mesh.Mesh) = undefined;

var cube_mesh: delve.graphics.mesh.Mesh = undefined;

var map_transform: math.Mat4 = undefined;

var bounding_box_size: math.Vec3 = math.Vec3.new(2, 3, 2);
var player_pos: math.Vec3 = math.Vec3.zero;
var player_vel: math.Vec3 = math.Vec3.zero;
var on_ground = true;

var gravity: f32 = -0.5;

pub fn main() !void {
    const example = delve.modules.Module{
        .name = "quakemap_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
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

    // test out registering a console command and a console variable
    try delve.debug.registerConsoleCommand("setGravity", setGravityCmd, "Changes gravity");
    try delve.debug.registerConsoleVariable("gravity", &gravity, "Amount of gravity");

    try app.start(app.AppConfig{ .title = "Delve Framework - Quake Map Example" });
}

pub fn on_init() !void {
    const fallback_tex = graphics.createDebugTexture();

    const test_map_file =
        \\// Game: Generic
        \\// Format: Standard
        \\// entity 0
        \\{
        \\"classname" "worldspawn"
        \\// brush 0
        \\{
        \\( -64 -64 -16 ) ( -64 -63 -16 ) ( -64 -64 -15 ) tech_14 0 0 0 1 1
        \\( -64 -64 -16 ) ( -64 -64 -15 ) ( -63 -64 -16 ) tech_14 0 0 0 1 1
        \\( -64 -64 -16 ) ( -63 -64 -16 ) ( -64 -63 -16 ) tech_14 0 0 0 1 1
        \\( 64 64 16 ) ( 64 65 16 ) ( 65 64 16 ) tech_11 0 0 0 1 1
        \\( 64 64 16 ) ( 65 64 16 ) ( 64 64 17 ) tech_14 0 0 0 1 1
        \\( 64 64 16 ) ( 64 64 17 ) ( 64 65 16 ) tech_14 0 0 0 1 1
        \\}
        \\// brush 1
        \\{
        \\( -64 32 16 ) ( -64 33 16 ) ( -64 32 17 ) tech_9 0 0 0 1 1
        \\( -64 32 16 ) ( -64 32 17 ) ( -63 32 16 ) tech_2 0 0 0 1 1
        \\( -64 32 16 ) ( -63 32 16 ) ( -64 33 16 ) tech_2 0 0 0 1 1
        \\( 64 64 96 ) ( 64 65 96 ) ( 65 64 96 ) tech_2 16 0 0 1 1
        \\( 64 64 32 ) ( 65 64 32 ) ( 64 64 33 ) tech_2 0 0 0 1 1
        \\( 64 64 32 ) ( 64 64 33 ) ( 64 65 32 ) tech_2 0 0 0 1 1
        \\}
        \\// brush 2
        \\{
        \\( -176 32 80 ) ( -176 33 80 ) ( -176 32 81 ) tech_2 0 0 0 1 1
        \\( -176 32 80 ) ( -176 32 81 ) ( -175 32 80 ) tech_2 0 0 0 1 1
        \\( -176 32 80 ) ( -175 32 80 ) ( -176 33 80 ) tech_2 0 0 0 1 1
        \\( -64 64 96 ) ( -64 65 96 ) ( -63 64 96 ) tech_2 0 0 0 1 1
        \\( -64 64 96 ) ( -63 64 96 ) ( -64 64 97 ) tech_2 0 0 0 1 1
        \\( -64 64 96 ) ( -64 64 97 ) ( -64 65 96 ) tech_2 0 0 0 1 1
        \\}
        \\// brush 3
        \\{
        \\( -176 32 96 ) ( -176 33 96 ) ( -176 32 97 ) tech_2 0 0 0 1 1
        \\( -176 32 96 ) ( -176 32 97 ) ( -175 32 96 ) tech_2 0 0 0 1 1
        \\( -176 32 96 ) ( -175 32 96 ) ( -176 33 96 ) tech_2 0 0 0 1 1
        \\( -144 64 192 ) ( -144 65 192 ) ( -143 64 192 ) tech_2 0 0 0 1 1
        \\( -144 64 112 ) ( -143 64 112 ) ( -144 64 113 ) tech_2 0 0 0 1 1
        \\( -144 64 112 ) ( -144 64 113 ) ( -144 65 112 ) tech_2 0 0 90 1 1
        \\}
        \\// brush 4
        \\{
        \\( -144 32 176 ) ( -144 33 176 ) ( -144 32 177 ) __TB_empty 0 0 0 1 1
        \\( -144 32 176 ) ( -144 32 177 ) ( -143 32 176 ) tech_3 0 0 0 1 1
        \\( -144 32 176 ) ( -143 32 176 ) ( -144 33 176 ) tech_12 0 0 0 1 1
        \\( -112 48 192 ) ( -112 49 192 ) ( -111 48 192 ) tech_3 0 0 0 1 1
        \\( -112 48 192 ) ( -111 48 192 ) ( -112 48 193 ) tech_3 0 0 0 1 1
        \\( 0 48 192 ) ( 0 48 193 ) ( 0 49 192 ) tech_3 0 0 0 1 1
        \\}
        \\// brush 5
        \\{
        \\( 0 32 128 ) ( 0 48 128 ) ( -32 48 176 ) tech_9 0 0 0 1 1
        \\( 0 32 176 ) ( 16 32 128 ) ( 0 32 128 ) tech_13 0 0 0 1 1
        \\( 16 32 128 ) ( 16 48 128 ) ( 0 48 128 ) tech_9 0 0 0 1 1
        \\( -32 48 176 ) ( 0 48 176 ) ( 0 32 176 ) __TB_empty 0 0 0 1 1
        \\( 0 48 128 ) ( 16 48 128 ) ( 0 48 176 ) tech_9 0 0 0 1 1
        \\( 0 48 176 ) ( 16 48 128 ) ( 16 32 128 ) tech_9 0 0 0 1 1
        \\}
        \\// brush 6
        \\{
        \\( -144 64 112 ) ( -144 32 112 ) ( -144 32 96 ) tech_2 0 0 0 1 1
        \\( -128 32 112 ) ( -112 32 96 ) ( -144 32 96 ) tech_14 0 0 0 1 1
        \\( -112 32 96 ) ( -112 64 96 ) ( -144 64 96 ) tech_2 0 0 0 1 1
        \\( -144 64 112 ) ( -128 64 112 ) ( -128 32 112 ) tech_10 0 0 0 1 1
        \\( -144 64 96 ) ( -112 64 96 ) ( -128 64 112 ) tech_14 0 0 0 1 1
        \\( -128 64 112 ) ( -112 64 96 ) ( -112 32 96 ) tech_12 0 0 90 1 1
        \\}
        \\// brush 7
        \\{
        \\( -64 32 80 ) ( -64 0 80 ) ( -64 -48 16 ) tech_2 0 0 0 1 1
        \\( -64 0 80 ) ( -32 0 80 ) ( -32 -48 16 ) tech_6 0 0 90 1 1
        \\( -32 -48 16 ) ( -32 32 16 ) ( -64 32 16 ) __TB_empty 0 0 0 1 1
        \\( -64 32 80 ) ( -32 32 80 ) ( -32 0 80 ) tech_7 0 0 0 1 1
        \\( -32 32 16 ) ( -32 32 80 ) ( -64 32 80 ) __TB_empty 0 0 0 1 1
        \\( -32 0 80 ) ( -32 32 80 ) ( -32 32 16 ) tech_2 0 0 0 1 1
        \\}
        \\}
    ;

    const translate = delve.math.Mat4.translate(delve.math.Vec3.x_axis.scale(10.0));
    map_transform = delve.math.Mat4.scale(delve.math.Vec3.new(0.1, 0.1, 0.1)).mul(translate).mul(delve.math.Mat4.rotate(-90, delve.math.Vec3.x_axis));

    // const allocator = gpa.allocator();
    const allocator = std.heap.c_allocator;
    var err: delve.utils.quakemap.ErrorInfo = undefined;
    quake_map = try delve.utils.quakemap.QuakeMap.read(allocator, test_map_file, map_transform, &err);

    shader = try graphics.Shader.initFromBuiltin(.{ .vertex_attributes = delve.graphics.mesh.getShaderAttributes() }, delve.shaders.default_mesh);

    // Create a material out of the texture
    fallback_material = try graphics.Material.init(.{
        .shader = shader,
        .texture_0 = fallback_tex,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    fallback_quake_material = .{ .material = fallback_material };

    // create our camera
    camera = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 512, 16.0, math.Vec3.up);
    camera.position.y = 10.0;

    // set our player position too
    player_pos = camera.position;

    materials = std.StringHashMap(delve.utils.quakemap.QuakeMaterial).init(allocator);

    for (quake_map.worldspawn.solids.items) |solid| {
        for (solid.faces.items) |face| {
            var mat_name = std.ArrayList(u8).init(allocator);
            var tex_path = std.ArrayList(u8).init(allocator);
            try mat_name.writer().print("{s}", .{face.texture_name});
            try mat_name.append(0);
            try tex_path.writer().print("assets/textures/{s}.png", .{face.texture_name});
            try tex_path.append(0);

            const mat_name_owned = try mat_name.toOwnedSlice();
            const mat_name_null = mat_name_owned[0 .. mat_name_owned.len - 1 :0];

            const found = materials.get(mat_name_null);
            if (found == null) {
                const texpath = try tex_path.toOwnedSlice();
                const tex_path_null = texpath[0 .. texpath.len - 1 :0];

                var tex_img: delve.images.Image = delve.images.loadFile(tex_path_null) catch {
                    delve.debug.log("Could not load image: {s}", .{tex_path_null});
                    try materials.put(mat_name_null, .{ .material = fallback_material });
                    continue;
                };
                defer tex_img.deinit();
                const tex = graphics.Texture.init(tex_img);

                const mat = try graphics.Material.init(.{
                    .shader = shader,
                    .samplers = &[_]graphics.FilterMode{.NEAREST},
                    .texture_0 = tex,
                });
                try materials.put(mat_name_null, .{ .material = mat, .tex_size_x = @intCast(tex.width), .tex_size_y = @intCast(tex.height) });

                // delve.debug.log("Loaded image: {s}", .{tex_path_null});
            }
        }
    }

    // make meshes out of the quake map, one per material
    map_meshes = try quake_map.buildWorldMeshes(allocator, math.Mat4.identity, &materials, &fallback_quake_material);
    entity_meshes = try quake_map.buildEntityMeshes(allocator, math.Mat4.identity, &materials, &fallback_quake_material);

    // make a bounding box cube
    cube_mesh = try delve.graphics.mesh.createCube(math.Vec3.new(0, 0, 0), bounding_box_size, delve.colors.red, fallback_material);

    // set a bg color
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_light);

    delve.platform.app.captureMouse(true);
}

pub fn on_tick(delta: f32) void {
    if (delve.platform.input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();

    do_player_move(delta);

    // update camera position to new player pos
    camera.position = player_pos;
    camera.runSimpleCamera(0, 60 * delta, true);
}

pub fn on_draw() void {
    const view_mats = camera.update();
    const model = math.Mat4.identity;

    for (0..map_meshes.items.len) |idx| {
        map_meshes.items[idx].draw(view_mats, model);
    }
    for (0..entity_meshes.items.len) |idx| {
        entity_meshes.items[idx].draw(view_mats, model);
    }

    cube_mesh.draw(view_mats, math.Mat4.translate(camera.position));
}

pub fn do_player_move(delta: f32) void {
    // gravity!
    player_vel.y += gravity * delta;

    // get our forward input direction
    var move_dir: math.Vec3 = math.Vec3.zero;
    if (delve.platform.input.isKeyPressed(.W)) {
        var dir = camera.direction;
        dir.y = 0.0;
        dir = dir.norm();
        move_dir = move_dir.add(dir);
    }
    if (delve.platform.input.isKeyPressed(.S)) {
        var dir = camera.direction;
        dir.y = 0.0;
        dir = dir.norm();
        move_dir = move_dir.sub(dir);
    }

    // get our sideways input direction
    if (delve.platform.input.isKeyPressed(.D)) {
        const right_dir = camera.getRightDirection();
        move_dir = move_dir.add(right_dir);
    }
    if (delve.platform.input.isKeyPressed(.A)) {
        const right_dir = camera.getRightDirection();
        move_dir = move_dir.sub(right_dir);
    }

    // jumnp and fly
    if (delve.platform.input.isKeyJustPressed(.SPACE) and on_ground) player_vel.y = 0.3;
    if (delve.platform.input.isKeyPressed(.F)) player_vel.y = 0.1;

    move_dir = move_dir.norm();
    player_vel = player_vel.add(move_dir.scale(10.0).scale(delta));

    // horizontal collisions
    const check_bounds_x = delve.spatial.BoundingBox.init(player_pos.add(math.Vec3.new(player_vel.x, 0, 0)), bounding_box_size);
    var did_collide_x = false;
    for (quake_map.worldspawn.solids.items) |solid| {
        did_collide_x = solid.checkBoundingBoxCollision(check_bounds_x);
        if (did_collide_x)
            break;
    }
    if (did_collide_x)
        player_vel.x = 0.0;

    const check_bounds_z = delve.spatial.BoundingBox.init(player_pos.add(math.Vec3.new(player_vel.x, 0, player_vel.z)), bounding_box_size);
    var did_collide_z = false;
    for (quake_map.worldspawn.solids.items) |solid| {
        did_collide_z = solid.checkBoundingBoxCollision(check_bounds_z);
        if (did_collide_z)
            break;
    }
    if (did_collide_z)
        player_vel.z = 0.0;

    // vertical collision
    const check_bounds_y = delve.spatial.BoundingBox.init(player_pos.add(math.Vec3.new(player_vel.x, player_vel.y, player_vel.z)), bounding_box_size);
    var did_collide_y = false;
    for (quake_map.worldspawn.solids.items) |solid| {
        did_collide_y = solid.checkBoundingBoxCollision(check_bounds_y);
        if (did_collide_y)
            break;
    }
    if (did_collide_y) {
        on_ground = player_vel.y < 0.0;
        player_vel.y = 0.0;
    } else {
        on_ground = false;
    }

    // velocity has been clipped to collisions, can move now
    player_pos = player_pos.add(player_vel);

    // dumb friction!
    player_vel.x = 0.0;
    player_vel.z = 0.0;
}

pub fn setGravityCmd(new_gravity: f32) void {
    gravity = new_gravity;
    delve.debug.log("Changed gravity to {d}", .{gravity});
}

pub fn on_cleanup() !void {
    var it = materials.valueIterator();
    while (it.next()) |mat_ptr| {
        mat_ptr.material.deinit();
    }
    materials.deinit();
    shader.destroy();

    quake_map.deinit();
}
