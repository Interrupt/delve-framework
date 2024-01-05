const std = @import("std");
const math = @import("../math.zig");
const ziglua = @import("ziglua");
const main = @import("../main.zig");
const debug = @import("../debug.zig");
const assets = @import("assets.zig");
const images = @import("../images.zig");
const graphics = @import("../platform/graphics.zig");
const batcher = @import("../graphics/batcher.zig");
const scripting = @import("../scripting/manager.zig");

var enable_debug_logging = false;

var sprite_batch: batcher.SpriteBatcher = undefined;

// ------- Lifecycle functions --------
/// Called when the app is starting up
pub fn libInit() void {
    // since we will be drawing a view with 0,0 as the top left, and not bottom right,
    // flip the texture vertically!
    sprite_batch = batcher.SpriteBatcher.init(.{ .flip_tex_y = true }) catch {
        debug.log("Error initializing sprite batch!", .{});
        return;
    };
}

/// Called at the start of a frame
pub fn libTick(tick: u64) void {
    _ = tick;
    sprite_batch.reset();
}

/// Called at the end of a frame
pub fn libDraw() void {
    var view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 5 }, math.Vec3.zero(), math.Vec3.up());
    var model = math.Mat4.translate(.{ .x = 0.0, .y = 0.0, .z = -2.5 });

    graphics.setProjectionOrtho(0.001, 10.0, true);
    graphics.setView(view, model);

    sprite_batch.apply();
    sprite_batch.draw();
}

/// Called when things are shutting down
pub fn libCleanup() void {
    debug.log("Graphics API: cleanup", .{});
    sprite_batch.deinit();
}

/// Draws a section of an image to the screen
pub fn blit(texture_handle: u32, source_x: f32, source_y: f32, source_width: f32, source_height: f32, dest_x: f32, dest_y: f32, dest_width: f32, dest_height: f32) void {
    var loaded_tex: ?graphics.Texture = assets._getTextureFromHandle(texture_handle);
    if(loaded_tex == null)
        return;

    var loaded_img: ?images.Image = assets._getImageFromHandle(texture_handle);
    if(loaded_img == null)
        return;

    var transform = math.Mat4.translate(.{ .x = dest_x, .y = dest_y, .z = 0.0 });
    sprite_batch.setTransformMatrix(transform);

    const x_aspect = 1.0 / @as(f32, @floatFromInt(loaded_img.?.width));
    const y_aspect = 1.0 / @as(f32, @floatFromInt(loaded_img.?.height));

    // Snip out just what we were asked to draw
    var region = batcher.TextureRegion {
        .u = @min(source_x * x_aspect, 1.0),
        .v = @min(source_y * y_aspect, 1.0),
        .v_2 = @min((source_y + source_height) * y_aspect, 1.0),
        .u_2 = @min((source_x + source_width) * x_aspect, 1.0),
    };

    sprite_batch.addRectangle(loaded_tex.?,
        math.Vec2{.x=0, .y=0},
        math.Vec2{.x=dest_width, .y=dest_height},
        region,
        0xFFFFFFFF);
}
