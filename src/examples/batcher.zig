const std = @import("std");
const batcher = @import("../graphics/batcher.zig");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const input = @import("../platform/input.zig");
const math = @import("../math.zig");
const modules = @import("../modules.zig");

var test_batch: batcher.Batcher = undefined;
var view: math.Mat4 = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 3.0 }, math.Vec3.zero(), math.Vec3.up());

pub fn registerModule() !void {
    const batcherExample = modules.Module {
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(batcherExample);
}

fn on_init() void {
    debug.log("Batch example module initializing", .{});

    test_batch = batcher.Batcher.init() catch {
        debug.showErrorScreen("Fatal error during batch init!");
        return;
    };
}

fn on_tick(tick: u64) void {
    test_batch.reset();
    for(0 .. 10000) |i| {
        const f_i = @as(f32, @floatFromInt(i));
        const x_pos = std.math.sin(@as(f32, @floatFromInt(tick * i)) * 0.0001) * (1.0 + (f_i * 0.05));
        const y_pos = std.math.cos(@as(f32, @floatFromInt(tick * i)) * 0.0001) * (0.5 + (f_i * 0.05));

        if(@mod(i, 2) != 0) {
            test_batch.addRectangle(x_pos, y_pos, f_i * -0.1, 0.5, 0.5, batcher.TextureRegion.default(), 0xFFFFFFFF);
        } else {
            test_batch.addTriangle(-x_pos, y_pos, f_i * -0.1, 0.5, 0.5, batcher.TextureRegion.default(), 0xFFFFFFFF);
        }
    }
    test_batch.apply();
}

fn on_draw() void {
    const mouse_pos = input.getMousePosition();
    const view_translate = math.Vec3 { .x = -3.5 + mouse_pos.x * 0.007, .y = 1 + -mouse_pos.y * 0.0075, .z = 0 };

    view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 6.0 }, math.Vec3.zero(), math.Vec3.up());
    view = math.Mat4.mul(view, math.Mat4.translate(view_translate));

    graphics.setView(view, math.Mat4.identity());
    test_batch.draw();
}

fn on_cleanup() void {
    debug.log("Batch example module cleaning up", .{});
}
