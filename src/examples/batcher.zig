const std = @import("std");
const batcher = @import("../graphics/batcher.zig");
const debug = @import("../debug.zig");
const images = @import("../images.zig");
const graphics = @import("../platform/graphics.zig");
const input = @import("../platform/input.zig");
const math = @import("../math.zig");
const modules = @import("../modules.zig");

pub const test_asset_1 = @embedFile("../static/test.gif");
pub const test_asset_2 = @embedFile("../static/test2.gif");

var texture_1: graphics.Texture = undefined;
var texture_2: graphics.Texture = undefined;

var test_batch: batcher.SpriteBatcher = undefined;
var view: math.Mat4 = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 3.0 }, math.Vec3.zero(), math.Vec3.up());

const stress_test_count = 10000;

pub fn registerModule() !void {
    const batcherExample = modules.Module {
        .name = "batcher_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(batcherExample);
}

fn on_init() void {
    debug.log("Batch example module initializing", .{});

    test_batch = batcher.SpriteBatcher.init(.{}) catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };

    // load some images
    var test_image_1 = images.loadBytes(test_asset_1) catch {
        debug.log("Could not load test texture", .{});
        return;
    };

    var test_image_2 = images.loadBytes(test_asset_2) catch {
        debug.log("Could not load test texture", .{});
        return;
    };

    // make some textures from our images
    texture_1 = graphics.Texture.init(&test_image_1);
    texture_2 = graphics.Texture.init(&test_image_2);
}

fn on_tick(tick: u64) void {
    test_batch.reset();
    for(0 .. stress_test_count) |i| {
        const f_i = @as(f32, @floatFromInt(i));
        const x_pos = std.math.sin(@as(f32, @floatFromInt(tick * i)) * 0.0001) * (1.0 + (f_i * 0.05));
        const y_pos = std.math.cos(@as(f32, @floatFromInt(tick * i)) * 0.0001) * (0.5 + (f_i * 0.05));

        if(@mod(i, 3) == 0) {
            test_batch.useTexture(texture_1);
        } else {
            test_batch.useTexture(texture_2);
        }

        var transform: math.Mat4 = undefined;
        if(@mod(i, 2) != 0) {
            transform = math.Mat4.translate(.{ .x = x_pos, .y = y_pos, .z = f_i * -0.1 });
            transform = math.Mat4.mul(transform, math.Mat4.rotate(f_i * 3.0, .{ .x = 1.0, .y = 1.0, .z = 0.0 }));
            test_batch.setTransformMatrix(transform);

            test_batch.addRectangle(0, 0, 0, 0.5, 0.5, batcher.TextureRegion.default(), 0xFFFFFFFF);
        } else {
            transform = math.Mat4.translate(.{ .x = -x_pos, .y = y_pos, .z = f_i * -0.1 });
            transform = math.Mat4.mul(transform, math.Mat4.rotate(f_i * 3.0, .{ .x = 0.0, .y = -1.0, .z = 0.0 }));
            test_batch.setTransformMatrix(transform);

            test_batch.addTriangle(0, 0, 0, 0.5, 0.5, batcher.TextureRegion.default(), 0xFFFFFFFF);
        }
    }
    test_batch.apply();
}

fn on_draw() void {
    const mouse_pos = input.getMousePosition();
    const view_translate = math.Vec3 { .x = -3.5 + mouse_pos.x * 0.007, .y = 1 + -mouse_pos.y * 0.0075, .z = 0 };

    view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 6.0 }, math.Vec3.zero(), math.Vec3.up());
    view = math.Mat4.mul(view, math.Mat4.translate(view_translate));
    view = math.Mat4.mul(view, math.Mat4.rotate(25.0, .{ .x = 0.0, .y = 1.0, .z = 0.0 }));

    graphics.setView(view, math.Mat4.identity());
    test_batch.draw();
}

fn on_cleanup() void {
    debug.log("Batch example module cleaning up", .{});
}
