const app = @import("../app.zig");
const debug = @import("../debug.zig");
const gfx = @import("graphics.zig");
const modules = @import("../modules.zig");
const time = @import("std").time;
const sokol_app_backend = @import("backends/sokol/app.zig");

// Actual app backend, implementation could be switched out here
const AppBackend = sokol_app_backend.App;

const state = struct {
    // FPS cap vars, if set
    var target_fps: ?u64 = null;
    var target_fps_ns: u64 = undefined;

    // Fixed timestamp length, if set
    var fixed_timestep_delta: ?f32 = null;

    // delta time vars
    var last_delta_calc: time.Instant = undefined;
    var reset_delta: bool = true;
    var time_accumulator: f32 = 0.0;

    // fps calc, every second
    var fps: i32 = 0;
    var fps_framecount: i64 = 0;
    var fps_start: time.Instant = undefined;
};

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

    if(config.use_fixed_timestep)
        setFixedTimestep(config.fixed_timestep_delta);

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
    var delta_time = calcDeltaTime();

    if(state.fixed_timestep_delta) |fixed_delta| {
        state.time_accumulator += delta_time;

        // keep ticking until we catch up to the actual time
        while(state.time_accumulator >= fixed_delta) {
            // fixed timestamp, tick at our constant rate
            modules.tickModules(fixed_delta);
            state.time_accumulator -= fixed_delta;
        }
    } else {
        // tick as fast as possible!
        modules.tickModules(delta_time);
    }

    // tell modules we are getting ready to draw!
    modules.preDrawModules();

    // then draw!
    gfx.startFrame();
    modules.drawModules();
    gfx.endFrame();

    // tell modules this frame is done
    modules.postDrawModules();
}

/// Get time elapsed since last tick. Also calculate the FPS!
fn calcDeltaTime() f32 {
    var now = time.Instant.now() catch { return 0; };
    defer state.fps_framecount += 1;

    if(state.reset_delta) {
        state.reset_delta = false;
        state.last_delta_calc = now;
        state.fps_start = now;
        state.fps_framecount = 0;
        return 0.0;
    }

    if(state.target_fps != null) {
        // Try to hit our target FPS!
        const frame_len_ns = now.since(state.last_delta_calc);

        if(frame_len_ns < state.target_fps_ns) {
            time.sleep(state.target_fps_ns - frame_len_ns);

            // reset our now, since we've pushed things back
            now = time.Instant.now() catch { return 0; };
        }
    }

    // calculate the fps by counting frames each second
    const nanos_since = now.since(state.last_delta_calc);
    const nanos_since_fps = now.since(state.fps_start);

    if(nanos_since_fps >= 1000000000) {
        state.fps = @intCast(state.fps_framecount);
        state.fps_framecount = 0;
        state.fps_start = now;
        // debug.log("FPS: {d}", .{fps});
    }

    state.last_delta_calc = now;
    return @as(f32, @floatFromInt(nanos_since)) / 1000000000.0;
}

/// Returns the current frames per second
pub fn getFPS() i32 {
    return state.fps;
}

/// Ask to reset the delta time, use to avoid hitching
pub fn resetDeltaTime() void {
    state.reset_delta = true;
}

/// Set a FPS target to aim for
pub fn setTargetFPS(fps_target: i32) void {
    state.target_fps = @intCast(fps_target);

    const target_fps_f: f64 = @floatFromInt(state.target_fps.?);
    state.target_fps_ns = @intFromFloat((1.0 / target_fps_f) * 1000000000);
}

pub fn setFixedTimestep(timestep_delta: f32) void {
    state.fixed_timestep_delta = timestep_delta;
}
