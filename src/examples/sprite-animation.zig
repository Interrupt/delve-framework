const std = @import("std");
const delve = @import("delve");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const graphics = delve.platform.graphics;

var sprite_texture: graphics.Texture = undefined;

var sprite_sheet: delve.graphics.sprites.AnimatedSpriteSheet = undefined;
var sprite_batch: delve.graphics.batcher.SpriteBatcher = undefined;
var sprite_animation: delve.graphics.sprites.PlayingAnimation = undefined;

var loop_delay_time: f32 = 0.0;

var test_material: graphics.Material = undefined;
var shader: graphics.Shader = undefined;

// This example shows how to draw animated sprites out of a sprite sheet

pub const module = delve.modules.Module{
    .name = "animated_sprite_example",
    .init_fn = on_init,
    .tick_fn = on_tick,
    .draw_fn = on_draw,
    .cleanup_fn = on_cleanup,
};

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
    try delve.app.start(delve.app.AppConfig{ .title = "Delve Framework - Animated Sprite" });
}

pub fn registerModule() !void {
    try delve.modules.registerModule(module);
}

fn on_init() !void {
    delve.debug.log("Sprite animation example module initializing", .{});

    sprite_batch = delve.graphics.batcher.SpriteBatcher.init(.{}) catch {
        delve.debug.showErrorScreen("Fatal error during batch init!");
        return;
    };

    var spritesheet_image = delve.images.loadFile("assets/sprites/cat-anim-sheet.png") catch {
        delve.debug.log("Could not load image", .{});
        return;
    };
    defer spritesheet_image.deinit();

    // make the texture to draw
    sprite_texture = graphics.Texture.init(spritesheet_image);

    // make our shader to draw with
    shader = try graphics.Shader.initDefault(.{});

    // make a material to draw with
    test_material = try graphics.Material.init(.{
        .shader = shader,
        .texture_0 = sprite_texture,
        .cull_mode = .BACK,
        .blend_mode = .NONE, // no alpha blending
        .samplers = &[_]graphics.FilterMode{.NEAREST}, // keep nice pixels!
    });

    delve.debug.log("Making spritesheet atlas", .{});

    // create a set of animations from our sprite sheet
    sprite_sheet = delve.graphics.sprites.AnimatedSpriteSheet.initFromGrid(1, 32, "cat_") catch {
        delve.debug.log("Could not create sprite sheet!", .{});
        return;
    };

    // add an extra long delay to a sleeping frame
    var anim = sprite_sheet.entries.getPtr("cat_0").?;
    anim.frames[29].duration = 24.0;

    // get and start the first animation
    sprite_animation = sprite_sheet.playAnimation("cat_0").?;
    sprite_animation.play();
    sprite_animation.setSpeed(16.0);

    graphics.setClearColor(delve.colors.examples_bg_light);
}

fn on_tick(deltatime: f32) void {
    // advance the animation
    sprite_animation.tick(deltatime);

    if (delve.platform.input.isKeyJustPressed(.ESCAPE)) {
        delve.platform.app.exit();
    }
}

fn on_draw() void {
    const cur_frame = sprite_animation.getCurrentFrame();

    // clear the batch for this frame
    sprite_batch.reset();

    // make sure we are using our material
    sprite_batch.useMaterial(test_material);

    // add our sprite rectangle
    const rect = delve.spatial.Rect.new(cur_frame.offset, cur_frame.size);
    sprite_batch.addRectangle(rect.centered(), cur_frame.region, delve.colors.white);

    // apply the batch to make it ready to draw!
    sprite_batch.apply();

    // setup our view to draw with
    const projection = graphics.getProjectionPerspective(60, 0.01, 20.0);
    const view = delve.math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 3.0 }, delve.math.Vec3.zero, delve.math.Vec3.up);

    // draw the sprite batch
    sprite_batch.draw(.{ .view = view, .proj = projection }, delve.math.Mat4.identity);
}

fn on_cleanup() !void {
    delve.debug.log("Sprite animation example module cleaning up", .{});
    sprite_texture.destroy();
    sprite_batch.deinit();
    sprite_sheet.deinit();
    shader.destroy();
    test_material.deinit();
}
