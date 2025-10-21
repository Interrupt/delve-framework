const std = @import("std");
const math = @import("../math.zig");
const zlua = @import("zlua");
const papp = @import("../platform/app.zig");
const debug = @import("../debug.zig");
const colors = @import("../colors.zig");
const assets = @import("assets.zig");
const images = @import("../images.zig");
const graphics = @import("../platform/graphics.zig");
const batcher = @import("../graphics/batcher.zig");
const sprites = @import("../graphics/sprites.zig");
const scripting = @import("../scripting/manager.zig");

const Rect = @import("../spatial/rect.zig").Rect;

var enable_debug_logging = false;

var sprite_batch: batcher.SpriteBatcher = undefined;

// ------- Lifecycle functions --------
/// Called when the app is starting up
pub fn libInit() !void {
    // since we will be drawing a view with 0,0 as the top left, and not bottom right,
    // flip the texture vertically!
    sprite_batch = batcher.SpriteBatcher.init(.{ .flip_tex_y = true }) catch {
        debug.log("Error initializing sprite batch!", .{});
        return;
    };
}

/// Called before drawing
pub fn libPreDraw() void {
    sprite_batch.reset();
}

/// Called when ready to draw
pub fn libDraw() void {
    const view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 5 }, math.Vec3.zero, math.Vec3.up);
    const proj = graphics.getProjectionOrtho(0.001, 10.0, true);
    const model = math.Mat4.translate(.{ .x = 0.0, .y = 0.0, .z = -2.5 });

    sprite_batch.apply();
    sprite_batch.draw(.{ .view = view, .proj = proj }, model);
}

/// Called when things are shutting down
pub fn libCleanup() !void {
    debug.log("Graphics API: cleanup", .{});
    sprite_batch.deinit();
}

/// Draws a section of an image to the screen
pub fn blit(texture_handle: u32, source_x: f32, source_y: f32, source_width: f32, source_height: f32, dest_x: f32, dest_y: f32, dest_width: f32, dest_height: f32) void {
    const loaded_tex: ?graphics.Texture = assets._getTextureFromHandle(texture_handle);
    if (loaded_tex == null)
        return;

    const loaded_img: ?images.Image = assets._getImageFromHandle(texture_handle);
    if (loaded_img == null)
        return;

    const transform = math.Mat4.translate(.{ .x = dest_x, .y = dest_y, .z = 0.0 });
    sprite_batch.setTransformMatrix(transform);

    const x_aspect = 1.0 / @as(f32, @floatFromInt(loaded_img.?.width));
    const y_aspect = 1.0 / @as(f32, @floatFromInt(loaded_img.?.height));

    // Snip out just what we were asked to draw
    const region = sprites.TextureRegion{
        .u = @min(source_x * x_aspect, 1.0),
        .v = @min(source_y * y_aspect, 1.0),
        .v_2 = @min((source_y + source_height) * y_aspect, 1.0),
        .u_2 = @min((source_x + source_width) * x_aspect, 1.0),
    };

    const draw_rect = Rect{ .x = 0, .y = 0, .width = dest_width, .height = dest_height };

    sprite_batch.useTexture(loaded_tex.?);
    sprite_batch.addRectangle(draw_rect, region, colors.white);
}
