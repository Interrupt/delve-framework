const app = @import("../app.zig");
const debug = @import("../debug.zig");
const gfx = @import("graphics.zig");
const modules = @import("../modules.zig");
const time = @import("std").time;
const sokol_app_backend = @import("backends/sokol/app.zig");

// Actual app backend, implementation could be switched out here
const AppBackend = sokol_app_backend.App;

var target_fps: ?u64 = null;
var target_fps_ns: u64 = undefined;

pub fn init() !void {
    debug.log("App starting", .{});

    AppBackend.init(.{
        .on_init_fn = on_init,
        .on_cleanup_fn = on_cleanup,
        .on_frame_fn = on_frame,
    });
}

pub fn deinit() void {
    debug.log("App stopping", .{});
    AppBackend.deinit();
}

pub fn startMainLoop(config: app.AppConfig) void {
    if(config.target_fps) |target|
        setTargetFPS(target);

    AppBackend.startMainLoop(config);
}

pub fn getWidth() i32 {
    return AppBackend.getWidth();
}

pub fn getHeight() i32 {
    return AppBackend.getHeight();
}

pub fn getAspectRatio() f32 {
    return @as(f32, @floatFromInt(getWidth())) / @as(f32, @floatFromInt(getHeight()));
}

fn on_init() void {
    // Start graphics first
    gfx.init() catch {
        debug.log("Fatal error initializing graphics backend!\n", .{});
        return;
    };

    // Now that there is an app and graphics context, we can start the app subsystems
    app.startSubsystems() catch {
        debug.log("Fatal error starting subsystems!\n", .{});
        return;
    };

    // initialize modules finally
    modules.initModules();

    // then kick everything off!
    modules.startModules();
}

fn on_cleanup() void {
    modules.stopModules();
    modules.cleanupModules();
    app.stopSubsystems();
    gfx.deinit();
}

fn on_frame() void {
    // time management!
    const delta_time = calcDeltaTime();

    // tick first
    modules.tickModules(delta_time);

    // then draw!
    gfx.startFrame();
    modules.drawModules();
    gfx.endFrame();

    // tell modules this frame is done
    modules.postDrawModules();
}

var last_delta_calc: time.Instant = undefined;
var reset_delta: bool = true;

var fps: i32 = 0;
var fps_framecount: i64 = 0;
var fps_start: time.Instant = undefined;

/// Get time elapsed since last tick. Also calculate the FPS!
fn calcDeltaTime() f32 {
    var now = time.Instant.now() catch { return 0; };
    defer fps_framecount += 1;

    if(reset_delta) {
        reset_delta = false;
        last_delta_calc = now;
        fps_start = now;
        fps_framecount = 0;
        return 0.0;
    }

    if(target_fps != null) {
        // Try to hit our target FPS!
        const frame_len_ns = now.since(last_delta_calc);

        if(frame_len_ns < target_fps_ns) {
            time.sleep(target_fps_ns - frame_len_ns);

            // reset our now, since we've pushed things back
            now = time.Instant.now() catch { return 0; };
        }
    }

    // calculate the fps by counting frames each second
    const nanos_since = now.since(last_delta_calc);
    const nanos_since_fps = now.since(fps_start);

    if(nanos_since_fps >= 1000000000) {
        fps = @intCast(fps_framecount);
        fps_framecount = 0;
        fps_start = now;
        // debug.log("FPS: {d}", .{fps});
    }

    last_delta_calc = now;
    return @as(f32, @floatFromInt(nanos_since)) / 1000000000.0;
}

/// Returns the current frames per second
pub fn getFPS() i32 {
    return fps;
}

/// Ask to reset the delta time, use to avoid hitching
pub fn resetDeltaTime() void {
    reset_delta = true;
}

/// Set a FPS target to aim for
pub fn setTargetFPS(fps_target: i32) void {
    target_fps = @intCast(fps_target);

    const target_fps_f: f64 = @floatFromInt(target_fps.?);
    target_fps_ns = @intFromFloat((1.0 / target_fps_f) * 1000000000);
}
