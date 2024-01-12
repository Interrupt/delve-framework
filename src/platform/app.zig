const app = @import("../app.zig");
const debug = @import("../debug.zig");
const gfx = @import("graphics.zig");
const modules = @import("../modules.zig");
const sokol_app_backend = @import("backends/sokol/app.zig");

// Actual app backend, implementation could be switched out here
const AppBackend = sokol_app_backend.App;

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
    AppBackend.startMainLoop(config);
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

var tick: u64 = 0;
fn on_frame() void {
    tick += 1;

    // tick first
    modules.tickModules(tick);

    // then draw!
    gfx.startFrame();
    modules.drawModules();
    gfx.endFrame();

    // tell modules this frame is done
    modules.postDrawModules();
}
