const std = @import("std");
const app = @import("../app.zig");
const debug = @import("../debug.zig");
const gfx = @import("graphics.zig");
const mem = @import("../mem.zig");
const modules = @import("../modules.zig");
const time = @import("std").time;
const sokol_app_backend = @import("backends/sokol/app.zig");

// Actual app backend, implementation could be switched out here
const AppBackend = sokol_app_backend.App;

const NS_PER_SECOND: i64 = 1_000_000_000;
const NS_PER_SECOND_F: f32 = 1_000_000_000.0;
const NS_FPS_LIMIT_OVERHEAD = 1_250_000; // tuned to ensure consistent frame pacing

const DeltaTime = struct {
    f_delta_time: f32,
    ns_delta_time: u64,
};

const state = struct {
    // FPS cap vars, if set
    var target_fps: ?u64 = null;
    var target_fps_ns: u64 = undefined;

    // Fixed timestep length - defaults to 40 per second
    var fixed_timestep_delta_ns: ?u64 = @intFromFloat((1.0 / 40.0) * NS_PER_SECOND_F);
    var fixed_timestep_delta_f: f32 = 1.0 / 40.0;
    var fixed_timestep_lerp: f32 = 0.0;

    // game loop timers
    var game_loop_timer: time.Timer = undefined;
    var fps_update_timer: time.Timer = undefined;
    var did_limit_fps: bool = false;

    // delta time vars
    var reset_delta: bool = true;

    // fixed tick game loops need to keep track of a time accumulator
    var time_accumulator_ns: u64 = 0;

    // current fps, updated every second
    var fps: i32 = 0;
    var fps_framecount: i64 = 0;

    // current tick
    var tick: u64 = 0;

    // current delta time
    var delta_time: f32 = 0.0;

    // current elapsed time
    var game_time: f64 = 0.0;

    var mouse_captured: bool = false;
};

pub fn init() !void {
    debug.log("App platform starting", .{});

    AppBackend.init(.{
        .on_init_fn = on_init,
        .on_cleanup_fn = on_cleanup,
        .on_frame_fn = on_frame,
        .on_resize_fn = on_resize,
    });

    state.game_loop_timer = try time.Timer.start();
    state.fps_update_timer = try time.Timer.start();
}

pub fn deinit() void {
    debug.log("App platform stopping", .{});
    AppBackend.deinit();
}

pub fn startMainLoop(config: app.AppConfig) void {
    if (config.target_fps) |target|
        setTargetFPS(target);

    if (config.use_fixed_timestep)
        setFixedTimestep(config.fixed_timestep_delta);

    AppBackend.startMainLoop(config);
}

pub fn getWidth() i32 {
    return AppBackend.getWidth();
}

pub fn getHeight() i32 {
    return AppBackend.getHeight();
}

pub fn captureMouse(captured: bool) void {
    state.mouse_captured = captured;
    AppBackend.captureMouse(captured);
}

pub fn isMouseCaptured() bool {
    return state.mouse_captured;
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
    debug.deinit();
    mem.deinit();
}

fn on_frame() void {
    // time management!
    const delta = calcDeltaTime();
    state.delta_time = delta.f_delta_time;
    state.game_time += state.delta_time;

    state.tick += 1;
    state.fps_framecount += 1;

    if (state.fixed_timestep_delta_ns) |fixed_delta_ns| {
        state.time_accumulator_ns += delta.ns_delta_time;

        // keep ticking until we catch up to the actual time
        while (state.time_accumulator_ns >= fixed_delta_ns) {
            // fixed timestamp, tick at our constant rate
            modules.fixedTickModules(state.fixed_timestep_delta_f);
            state.time_accumulator_ns -= fixed_delta_ns;
        }

        // store how far to the next fixed timestep we are
        state.fixed_timestep_lerp = @as(f32, @floatFromInt(state.time_accumulator_ns)) / @as(f32, @floatFromInt(fixed_delta_ns));
    }

    modules.tickModules(state.delta_time);
    // tell modules we are getting ready to draw!
    modules.preDrawModules();

    // then draw!
    gfx.startFrame();
    modules.drawModules();
    gfx.endFrame();

    // tell modules this frame is done
    modules.postDrawModules();

    // keep under our FPS limit, if needed
    state.did_limit_fps = limitFps();
}

fn on_resize() void {
    modules.onResizeModules();
}

fn limitFps() bool {
    if (state.target_fps == null)
        return false;

    // Try to hit our target FPS!

    // Easy case, just stop here if we are under the target frame length
    const initial_frame_ns = state.game_loop_timer.read();
    if (initial_frame_ns >= state.target_fps_ns)
        return false;

    // Harder case, we are faster than the target frame length.
    // Note: time.sleep does not ensure consistent timing.
    // Due to this we need to sleep most of the time, but busy loop the rest.

    const frame_len_ns = initial_frame_ns + NS_FPS_LIMIT_OVERHEAD;
    if (frame_len_ns < state.target_fps_ns) {
        time.sleep(state.target_fps_ns - frame_len_ns);
    }

    // Eat up the rest of the time in a busy loop to ensure consistent frame pacing
    while (true) {
        const cur_frame_len_ns = state.game_loop_timer.read();
        if (cur_frame_len_ns + 500 >= state.target_fps_ns)
            break;
    }

    return true;
}

/// Get time elapsed since last tick. Also calculate the FPS!
fn calcDeltaTime() DeltaTime {
    if (state.reset_delta) {
        state.reset_delta = false;
        state.game_loop_timer.reset();
        return DeltaTime{ .f_delta_time = 1.0 / 60.0, .ns_delta_time = 60 / NS_PER_SECOND };
    }

    // calculate the fps by counting frames each second
    const nanos_since_tick = state.game_loop_timer.lap();
    const nanos_since_fps = state.fps_update_timer.read();

    if (nanos_since_fps >= NS_PER_SECOND) {
        state.fps = @intCast(state.fps_framecount);
        state.fps_update_timer.reset();
        state.fps_framecount = 0;
    }

    // if(state.did_limit_fps) {
    //     return DeltaTime{
    //         .f_delta_time = (@as(f32, @floatFromInt(state.target_fps_ns)) / NS_PER_SECOND_F),
    //         .ns_delta_time = state.target_fps_ns,
    //     };
    // }

    return DeltaTime{
        .f_delta_time = @as(f32, @floatFromInt(nanos_since_tick)) / NS_PER_SECOND_F,
        .ns_delta_time = nanos_since_tick,
    };
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
    state.target_fps_ns = @intFromFloat((1.0 / target_fps_f) * NS_PER_SECOND);
}

/// Sets our fixed timestep rate. eg: 1.0 / 60.0 for 60 per second
pub fn setFixedTimestep(timestep_delta: f32) void {
    state.fixed_timestep_delta_ns = @intFromFloat(timestep_delta * NS_PER_SECOND_F);
    state.fixed_timestep_delta_f = timestep_delta;
}

/// Returns the current delta time for this frame
pub fn getCurrentDeltaTime() f32 {
    return state.delta_time;
}

/// Returns the time elapsed from game start
pub fn getTime() f64 {
    return state.game_time;
}

/// Returns our current tick number
pub fn getCurrentTick() u64 {
    return state.tick;
}

/// Returns how far to the next fixed timestep tick we are in the  0..0 to 1.0 range
/// When the delta is included, also gets premultiplied by the fixed timestep frame delta
pub fn getFixedTimestepLerp(include_delta: bool) f32 {
    if (include_delta)
        return state.fixed_timestep_delta_f * state.fixed_timestep_lerp;

    return state.fixed_timestep_lerp;
}

/// Exit cleanly
pub fn exit() void {
    sokol_app_backend.exit();
}

/// Exit with an error
pub fn exitWithError() void {
    std.posix.exit(1);
}

// Start a new Imgui frame
pub fn startImguiFrame() void {
    sokol_app_backend.startImguiFrame();
}

// Render Imgui
pub fn renderImgui() void {
    sokol_app_backend.renderImgui();
}
