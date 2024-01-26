const std = @import("std");
const delve = @import("delve");
const app = delve.app;

const RndGen = std.rand.DefaultPrng;

const batcher = delve.graphics_batcher;
const debug = delve.debug;
const cam = delve.graphics_camera;
const colors = delve.colors;
const images = delve.images;
const graphics = delve.graphics;
const input = delve.input;
const papp = delve.platform_app;
const math = delve.math;
const modules = delve.modules;
const fps_module = delve.module_fps_counter;

var tex_treesheet: graphics.Texture = undefined;
var shader_blend: graphics.Shader = undefined;

var sprite_batch: batcher.SpriteBatcher = undefined;
var grass_batch: batcher.SpriteBatcher = undefined;
var camera: cam.Camera = undefined;

// This is an example of using the sprite batcher to draw a forest!
// shows off: sprite batches, texture regions, billboarding, cameras

pub fn main() !void {
    try registerModule();
    try fps_module.registerModule();
    try app.start(app.AppConfig{ .title = "Delve Framework - Sprite Batch Forest Example" });
}

pub fn registerModule() !void {
    const forestExample = modules.Module{
        .name = "forest_example",
        .init_fn = on_init,
        .pre_draw_fn = pre_draw,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(forestExample);
}

const grass_sprites: []const batcher.TextureRegion = &[_]batcher.TextureRegion{
    batcher.TextureRegion{ // grass 1
        .u = 0.0,
        .v = 0.8,
        .u_2 = 0.05,
        .v_2 = 1.0,
    },
    batcher.TextureRegion{ // grass 2
        .u = 0.05,
        .v = 0.8,
        .u_2 = 0.128,
        .v_2 = 1.0,
    },
    batcher.TextureRegion{ // grass 3
        .u = 0.128,
        .v = 0.8,
        .u_2 = 0.2,
        .v_2 = 1.0,
    },
    batcher.TextureRegion{ // grass 4
        .u = 0.2,
        .v = 0.8,
        .u_2 = 0.275,
        .v_2 = 1.0,
    },
};

const tree_sprites: []const batcher.TextureRegion = &[_]batcher.TextureRegion{
    batcher.TextureRegion{ // fir tall
        .u = 0.275,
        .v = 0.015,
        .u_2 = 0.49,
        .v_2 = 1.0,
    },
    batcher.TextureRegion{ // fir tall bare
        .u = 0.49,
        .v = 0.1,
        .u_2 = 0.6,
        .v_2 = 1.0,
    },
    batcher.TextureRegion{ // fir small
        .u = 0.6,
        .v = 0.6,
        .u_2 = 0.7,
        .v_2 = 1.0,
    },
    batcher.TextureRegion{ // aspen
        .u = 0.85,
        .v = 0.0,
        .u_2 = 1.0,
        .v_2 = 1.0,
    },
};

// color palette!
var sky_color = colors.Color.newBytes(255, 247, 229, 255);
var ground_color = colors.Color.newBytes(255, 179, 105, 255).mul(colors.light_grey);
var foliage_tint = colors.white;

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

fn on_init() void {
    debug.log("Forest example module initializing", .{});

    sprite_batch = batcher.SpriteBatcher.init(.{}) catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };

    grass_batch = batcher.SpriteBatcher.init(.{}) catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };

    // Load some trees in a spritesheet
    const treesheet_path = "sprites/treesheet.png";
    var treesheet_img: images.Image = images.loadFile(treesheet_path) catch {
        debug.log("Assets: Error loading image asset: {s}", .{treesheet_path});
        return;
    };
    tex_treesheet = graphics.Texture.init(&treesheet_img);

    // make our default shader
    shader_blend = graphics.Shader.initDefault(.{ .blend_mode = .NONE, .cull_mode = .NONE });

    // set the sky color
    graphics.setClearColor(sky_color);

    // Make a perspective camera, with a 90 degree FOV
    camera = cam.Camera.init(90.0, 0.01, 100.0, math.Vec3.up());
    camera.position = math.Vec3.new(0.0, 0.0, -foliage_spread / 2);
    camera.direction = math.Vec3.new(0.0, 0.0, 1.0);
}

fn on_tick(delta: f32) void {
    camera.runFlyCamera(40 * delta, true);
    camera.position.y = 1.0;

    if (input.isKeyJustPressed(.ESCAPE)) {
        std.os.exit(0);
    }
}

var time: f64 = 0.0;
fn pre_draw() void {
    var rnd = RndGen.init(0); // reset the random seed every frame
    var random = rnd.random();

    time += delve.platform_app.getCurrentDeltaTime();

    // set up a matrix that will billboard to face the camera, but ignore the up dir
    var billboard_dir = math.Vec3.new(camera.direction.x, 0, camera.direction.z).norm();
    var rot_matrix = math.Mat4.direction(billboard_dir, camera.up);

    // make our grass, if needed
    addGrass();

    // reset the sprite batch to clear everything that was added for the previous frame
    sprite_batch.reset();

    // add a ground plane
    sprite_batch.useShader(shader_blend);
    sprite_batch.useTexture(graphics.tex_white);

    const ground_size = math.Vec2.new(foliage_spread, foliage_spread);
    var ground_transform = math.Mat4.translate(math.Vec3.new(0, draw_y_offset, (ground_size.y * -0.5)));
    ground_transform = ground_transform.mul(math.Mat4.rotate(90, math.Vec3.new(1, 0, 0)));
    sprite_batch.setTransformMatrix(ground_transform);

    sprite_batch.addRectangle(ground_size.scale(-0.5), ground_size, batcher.TextureRegion.default(), ground_color);

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
        var make_grass: bool = random.float(f32) < 0.8;
        var atlas = if (make_grass) grass_sprites else tree_sprites;
        var foliage_scale: f32 = if (make_grass) grass_scale else tree_scale;

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
        sprite_batch.addRectangle(math.Vec2{ .x = size.x * -0.5, .y = 0 }, size, tex_region, foliage_tint);
    }

    sprite_batch.apply();
}

var last_grass_position: math.Vec3 = undefined;
var made_grass: bool = false;
fn addGrass() void {
    const pos = camera.position;
    const grass_area: f32 = 30;
    const grass_size: f32 = 2.0;

    // only remake the grass when we have moved far enough since last time
    if (made_grass and pos.sub(last_grass_position).len() < 5)
        return;

    // keep track of when we did this last!
    made_grass = true;
    last_grass_position = pos;

    const grass_width: f32 = grass_area / 2.0;
    const start_x_pos: f32 = std.math.floor(pos.x);
    const start_z_pos: f32 = std.math.floor(pos.z);

    grass_batch.reset();
    grass_batch.useShader(shader_blend);
    grass_batch.useTexture(tex_treesheet);

    // we'll make grass in cells
    for (0..grass_area) |x| {
        for (0..grass_area) |z| {
            var fx: f32 = @floatFromInt(x);
            var fz: f32 = @floatFromInt(z);

            // cell position
            const xpos: f32 = start_x_pos + fx - (grass_width);
            const zpos: f32 = start_z_pos + fz - (grass_width);

            // seed random from this cell position
            var rnd = RndGen.init(std.math.absCast(@as(i32, @intFromFloat(xpos + (zpos * 10000)))));
            var random = rnd.random();

            // make multiple grass pieces for this cell!
            for (0..10) |_| {
                const x_offset: f32 = random.float(f32) - 0.5;
                const z_offset: f32 = random.float(f32) - 0.5;
                const tex_region = grass_sprites[random.intRangeLessThan(usize, 0, grass_sprites.len)];

                var draw_pos = math.Vec3.new(xpos + x_offset, 0, zpos + z_offset);
                var rot_matrix = math.Mat4.rotate(random.float(f32) * 360, camera.up);
                var transform = math.Mat4.translate(draw_pos).mul(rot_matrix);

                grass_batch.setTransformMatrix(transform);

                // size the rectangle based on the size of the sprite in the atlas
                var size = tex_region.getSize().mul(math.Vec2.new(2.1, 1)).scale(grass_size);
                size = size.scale(1.0 + random.float(f32) * 0.5);

                // add some random scaling, then draw!
                grass_batch.addRectangle(math.Vec2{ .x = size.x * -0.5, .y = 0 }, size, tex_region, foliage_tint);
            }
        }
    }

    grass_batch.apply();
}

fn on_draw() void {
    const proj_view_mat = camera.getProjView();
    grass_batch.draw(proj_view_mat, math.Mat4.identity());
    sprite_batch.draw(proj_view_mat, math.Mat4.identity());
}

fn on_cleanup() void {
    debug.log("Forest example module cleaning up", .{});
}
