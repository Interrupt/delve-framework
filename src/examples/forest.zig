const std = @import("std");
const delve = @import("delve");
const app = delve.app;

const RndGen = std.rand.DefaultPrng;

const batcher = delve.graphics.batcher;
const debug = delve.debug;
const cam = delve.graphics.camera;
const colors = delve.colors;
const images = delve.images;
const graphics = delve.platform.graphics;
const input = delve.platform.input;
const papp = delve.platform.app;
const math = delve.math;
const modules = delve.modules;
const fps_module = delve.module.fps_counter;

const TextureRegion = delve.graphics.sprites.TextureRegion;
const Rect = delve.spatial.Rect;

var tex_treesheet: graphics.Texture = undefined;
var shader_blend: graphics.Shader = undefined;

var sprite_batch: batcher.SpriteBatcher = undefined;
var grass_batch: batcher.SpriteBatcher = undefined;
var cloud_batch: batcher.SpriteBatcher = undefined;

var camera: cam.Camera = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub const module = modules.Module{
    .name = "forest_example",
    .init_fn = on_init,
    .pre_draw_fn = pre_draw,
    .tick_fn = on_tick,
    .draw_fn = on_draw,
    .cleanup_fn = on_cleanup,
};

// This is an example of using the sprite batcher to draw a forest!
// shows off: sprite batches, texture regions, billboarding, cameras

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
    try fps_module.registerModule();
    try app.start(app.AppConfig{ .title = "Delve Framework - Sprite Batch Forest Example" });
}

pub fn registerModule() !void {
    try modules.registerModule(module);
}

const grass_sprites: []const TextureRegion = &[_]TextureRegion{
    TextureRegion{ // grass 1
        .u = 0.0,
        .v = 0.8,
        .u_2 = 0.05,
        .v_2 = 1.0,
    },
    TextureRegion{ // grass 2
        .u = 0.05,
        .v = 0.8,
        .u_2 = 0.128,
        .v_2 = 1.0,
    },
    TextureRegion{ // grass 3
        .u = 0.128,
        .v = 0.8,
        .u_2 = 0.2,
        .v_2 = 1.0,
    },
    TextureRegion{ // grass 4
        .u = 0.2,
        .v = 0.8,
        .u_2 = 0.275,
        .v_2 = 1.0,
    },
};

const tree_sprites: []const TextureRegion = &[_]TextureRegion{
    TextureRegion{ // fir tall
        .u = 0.275,
        .v = 0.015,
        .u_2 = 0.49,
        .v_2 = 1.0,
    },
    TextureRegion{ // fir tall bare
        .u = 0.49,
        .v = 0.1,
        .u_2 = 0.6,
        .v_2 = 1.0,
    },
    TextureRegion{ // fir small
        .u = 0.6,
        .v = 0.6,
        .u_2 = 0.7,
        .v_2 = 1.0,
    },
    TextureRegion{ // aspen
        .u = 0.85,
        .v = 0.0,
        .u_2 = 1.0,
        .v_2 = 1.0,
    },
};

const cloud_sprites: []const TextureRegion = &[_]TextureRegion{
    TextureRegion{ // cloud 1
        .u = 0.0,
        .v = 0.0,
        .u_2 = 0.20,
        .v_2 = 0.31,
    },
    TextureRegion{ // cloud 2
        .u = 0.0,
        .v = 0.31,
        .u_2 = 0.20,
        .v_2 = 0.625,
    },
};

const grass_state = struct {
    var last_position: math.Vec3 = undefined;
    var made: bool = false;
};

// color palette!
var sky_color = colors.Color.newBytes(218, 203, 168, 255);
var ground_color = colors.Color.newBytes(255, 179, 105, 255).mul(colors.light_grey);
var foliage_tint = colors.white;
var cloud_tint = colors.white;

// alternate night colors
// var sky_color = colors.Color.newBytes(20, 20, 80, 255).mul(colors.grey);
// var ground_color = colors.navy.mul(colors.dark_grey);
// var foliage_tint = colors.navy.mul(colors.grey);

// draw options
var draw_y_offset: f32 = -0.2;
var tree_scale: f32 = 7.0;
var grass_scale: f32 = 4.0;
var size_variance: f32 = 0.25;
var foliage_count: u32 = 3200;
var foliage_spread: f32 = 120.0;

fn on_init() !void {
    debug.log("Forest example module initializing", .{});

    // capture and hide the mouse!
    papp.captureMouse(true);

    // set a FPS limit and fixed timestep to test that as well
    papp.setTargetFPS(60);
    papp.setFixedTimestep(1.0 / 60.0);

    // Load some trees in a spritesheet
    const treesheet_path = "assets/sprites/treesheet.png";
    var treesheet_img: images.Image = delve.images.loadFile(treesheet_path) catch {
        debug.log("Assets: Error loading image asset: {s}", .{treesheet_path});
        return;
    };
    defer treesheet_img.deinit();

    sprite_batch = batcher.SpriteBatcher.init(.{}) catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };

    grass_batch = batcher.SpriteBatcher.init(.{}) catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };

    cloud_batch = batcher.SpriteBatcher.init(.{}) catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };

    tex_treesheet = graphics.Texture.init(treesheet_img);

    // make our default shader
    shader_blend = try graphics.Shader.initDefault(.{ .blend_mode = .NONE, .cull_mode = .NONE });

    // set the sky color
    graphics.setClearColor(sky_color);

    // Make a perspective camera, with a 90 degree FOV
    camera = cam.Camera.init(90.0, 0.01, 100.0, math.Vec3.up);
    camera.move_mode = .WALK;

    camera.position = math.Vec3.new(0.0, 1.0, -foliage_spread / 2);
    camera.direction = math.Vec3.new(0.0, 0.0, 1.0);
}

fn on_tick(delta: f32) void {
    camera.runSimpleCamera(4.0 * delta, 120.0 * delta, true);

    if (input.isKeyJustPressed(.ESCAPE)) {
        papp.exit();
    }
}

var time: f64 = 0.0;
fn pre_draw() void {
    var rnd = RndGen.init(0); // reset the random seed every frame
    var random = rnd.random();

    time += papp.getCurrentDeltaTime();

    // set up a matrix that will billboard to face the camera, but ignore the up dir
    const billboard_dir = math.Vec3.new(camera.direction.x, 0, camera.direction.z).scale(-1);
    const rot_matrix = math.Mat4.billboard(billboard_dir, camera.up);

    // make our grass, if needed
    // addGrass(camera.position, 30, 1.25, 1.0);
    addClouds(0.12);

    // reset the sprite batch to clear everything that was added for the previous frame
    sprite_batch.reset();

    // make the ground plane
    addGround(math.Vec2.new(foliage_spread, foliage_spread));

    // now add all the foliage
    for (0..foliage_count) |i| {
        _ = i;
        sprite_batch.useTexture(tex_treesheet);

        // give each piece of foliage a random position
        const x_pos: f32 = (random.float(f32) * foliage_spread) - foliage_spread * 0.5;
        const z_pos: f32 = (random.float(f32) * foliage_spread) - foliage_spread;

        var transform = math.Mat4.translate(math.Vec3.new(x_pos, draw_y_offset, z_pos));
        transform = transform.mul(rot_matrix);

        // make mostly grass
        const make_grass: bool = random.float(f32) < 0.8;
        const atlas = if (make_grass) grass_sprites else tree_sprites;
        const foliage_scale: f32 = if (make_grass) grass_scale else tree_scale;

        // make foliage wave in the wind!
        const wave_offset: f32 = random.float(f32) * 1000.0;
        const wave_amount: f32 = if (make_grass) 5 else 1;
        const wave_speed: f32 = if (make_grass) 1 else 0.25;

        transform = transform.mul(math.Mat4.rotate(@floatCast(std.math.sin(wave_offset + time * wave_speed) * wave_amount), math.Vec3.new(0, 0, 1)));

        // have everything needed to tell the sprite batcher where to draw our sprite now
        sprite_batch.setTransformMatrix(transform);

        // grab a random region from the atlas
        const sprite_idx = random.intRangeLessThan(usize, 0, atlas.len);
        const tex_region = atlas[sprite_idx];

        // size the rectangle based on the size of the sprite in the atlas
        var reg_size = tex_region.getSize().mul(math.Vec2.new(2.1, 1)).scale(foliage_scale);

        // add some random scaling, then draw!
        const size = reg_size.scale(1.0 + random.float(f32) * (foliage_scale * size_variance));

        const rect = Rect.fromSize(size);
        sprite_batch.addRectangle(rect.centeredX(), tex_region, foliage_tint);
    }

    // save the state of the batch so it can be drawn
    sprite_batch.apply();
}

/// Add the ground plane to the sprite batch
fn addGround(ground_size: math.Vec2) void {
    sprite_batch.useShader(shader_blend);
    sprite_batch.useTexture(graphics.tex_white);

    // ground plane needs to be big enough to cover where the trees will be
    var ground_transform = math.Mat4.translate(math.Vec3.new(0, draw_y_offset, (ground_size.y * -0.5)));
    ground_transform = ground_transform.mul(math.Mat4.rotate(-90, math.Vec3.x_axis));

    // Add the ground plane rectangle
    sprite_batch.setTransformMatrix(ground_transform);

    const rect = Rect.fromSize(ground_size);
    sprite_batch.addRectangle(rect.centered(), TextureRegion.default(), ground_color);
}

/// Adds clouds to the cloud batch
fn addClouds(density: f32) void {
    var rnd = RndGen.init(0); // reset the random seed every frame
    var random = rnd.random();

    // set up a matrix that will billboard to face the camera
    const billboard_dir = camera.direction.scale(-1);
    const rot_matrix = math.Mat4.billboard(billboard_dir, camera.up);

    cloud_batch.useShader(shader_blend);
    cloud_batch.useTexture(tex_treesheet);
    cloud_batch.reset();

    const cloud_size: f32 = 90.0;
    const num_clouds: u32 = @intFromFloat(300.0 * density);

    for (0..num_clouds) |i| {
        _ = i;
        const tex_region = cloud_sprites[random.intRangeLessThan(u32, 0, cloud_sprites.len)];

        var draw_pos = math.Vec3.new(0, 0, -95);
        draw_pos = draw_pos.rotate(random.float(f32) * 80.0, math.Vec3.x_axis);
        draw_pos = draw_pos.rotate(random.float(f32) * 360.0 + @as(f32, @floatCast(time * 0.5)), math.Vec3.up);

        const transform = math.Mat4.translate(draw_pos).mul(rot_matrix);

        cloud_batch.setTransformMatrix(transform);

        // size the rectangle based on the size of the sprite in the atlas
        const size = tex_region.getSize().mul(math.Vec2.new(2.1, 1)).scale(cloud_size);

        const rect = Rect.fromSize(size);
        cloud_batch.addRectangle(rect.centered(), tex_region, cloud_tint);
    }
    cloud_batch.apply();
}

/// Makes grass in cells around the position.
fn addGrass(pos: math.Vec3, grass_area: u32, grass_size: f32, density: f32) void {
    // only remake the grass when we have moved far enough since last time
    if (grass_state.made and pos.sub(grass_state.last_position).len() < 5)
        return;

    // keep track of when we did this last!
    grass_state.made = true;
    grass_state.last_position = pos;

    const grass_width: f32 = @floatFromInt(grass_area / 2);
    const start_x_pos: f32 = std.math.floor(pos.x);
    const start_z_pos: f32 = std.math.floor(pos.z);

    grass_batch.reset();
    grass_batch.useShader(shader_blend);
    grass_batch.useTexture(tex_treesheet);

    // we'll make grass in cells
    for (0..grass_area) |x| {
        for (0..grass_area) |z| {
            const fx: f32 = @floatFromInt(x);
            const fz: f32 = @floatFromInt(z);

            // cell position
            const xpos: f32 = start_x_pos + fx - (grass_width);
            const zpos: f32 = start_z_pos + fz - (grass_width);

            // seed random from this cell position
            var rnd = RndGen.init(@abs(@as(i32, @intFromFloat(xpos + (zpos * 10000)))));
            var random = rnd.random();

            const grass_count: u32 = @intFromFloat(density * 10.0);

            // make multiple grass pieces for this cell!
            for (0..grass_count) |_| {
                const x_offset: f32 = random.float(f32) - 0.5;
                const z_offset: f32 = random.float(f32) - 0.5;

                const sprite_idx: usize = if (random.float(f32) < 0.85) 2 else 0;
                const tex_region = grass_sprites[sprite_idx];

                const draw_pos = math.Vec3.new(xpos + x_offset, 0, zpos + z_offset);
                const rot_matrix = math.Mat4.rotate(random.float(f32) * 360, camera.up);
                const transform = math.Mat4.translate(draw_pos).mul(rot_matrix);

                grass_batch.setTransformMatrix(transform);

                // size the rectangle based on the size of the sprite in the atlas
                var size = tex_region.getSize().mul(math.Vec2.new(2.1, 1)).scale(grass_size);
                size = size.scale(1.0 + random.float(f32) * 1);

                // add some random scaling, then draw!
                const rect = Rect.fromSize(size);
                grass_batch.addRectangle(rect.centeredX(), tex_region, foliage_tint);
            }
        }
    }

    // save the state of the grass batch so it can be drawn
    // this draw state will be kept until the next reset!
    grass_batch.apply();
}

fn on_draw() void {
    const view_mats = camera.update();

    // draw grass and trees
    grass_batch.draw(view_mats, math.Mat4.identity);
    sprite_batch.draw(view_mats, math.Mat4.identity);

    // make clouds follow the camera
    cloud_batch.draw(view_mats, math.Mat4.translate(camera.position));
}

fn on_cleanup() !void {
    debug.log("Forest example module cleaning up", .{});
    sprite_batch.deinit();
    cloud_batch.deinit();
    grass_batch.deinit();
    shader_blend.destroy();
}
