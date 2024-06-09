const std = @import("std");
const debug = @import("debug.zig");
const mem = @import("mem.zig");

var modules: std.StringArrayHashMap(Module) = undefined;
var needs_init: bool = true;

// don't put modules in the main list while iterating
var modules_to_add: std.StringArrayHashMap(Module) = undefined;

// whether we are in the middle of initializing the submodules
var is_initializing_modules: bool = false;

// Maybe we should store ArrayLists of functions to call instead of iterating through a map?
// - that would avoid a lot of checking for null when lots of moduels are registered

/// A Module is a named set of functions that tie into the app lifecycle
pub const Module = struct {
    name: [:0]const u8,
    init_fn: ?*const fn () anyerror!void = null,
    start_fn: ?*const fn () void = null,
    stop_fn: ?*const fn () void = null,
    tick_fn: ?*const fn (f32) void = null,
    fixed_tick_fn: ?*const fn (f32) void = null,
    pre_draw_fn: ?*const fn () void = null,
    draw_fn: ?*const fn () void = null,
    post_draw_fn: ?*const fn () void = null,
    cleanup_fn: ?*const fn () anyerror!void = null,

    // state properties
    did_init: bool = false,

    /// Runs the pre draw, draw, and post draw functions for this module. Useful when nesting modules.
    pub fn runFullRenderLifecycle(self: *const Module) void {
        if (self.pre_draw_fn != null) self.pre_draw_fn.?();
        if (self.draw_fn != null) self.draw_fn.?();
        if (self.post_draw_fn != null) self.post_draw_fn.?();
    }
};

/// Registers a module to tie it into the app lifecycle
pub fn registerModule(module: Module) !void {
    if (needs_init) {
        modules = std.StringArrayHashMap(Module).init(mem.getAllocator());
        modules_to_add = std.StringArrayHashMap(Module).init(mem.getAllocator());
        needs_init = false;
    }

    if (!is_initializing_modules) {
        // only allow one version of a module to be registered!
        try modules.putNoClobber(module.name, module);
        debug.log("Registered module: {s}", .{module.name});
        return;
    }

    // only allow one version of a module to be registered!
    try modules_to_add.putNoClobber(module.name, module);
    debug.log("Registered module: {s}", .{module.name});
}

/// Gets a registered module
pub fn getModule(module_name: [:0]const u8) ?Module {
    return modules.get(module_name);
}

/// Initialize all the modules
pub fn initModules() void {
    debug.log("Initializing modules!", .{});

    is_initializing_modules = true;

    var it = modules.iterator();
    while (it.next()) |module| {
        debug.log("Initializing module: {s}", .{module.value_ptr.name});
        if (module.value_ptr.init_fn != null)
            module.value_ptr.init_fn.?() catch {
                debug.err("Error initializing module: {s}", .{module.value_ptr.name});
                continue;
            };

        module.value_ptr.did_init = true;
    }

    is_initializing_modules = false;

    // If we registered more modules during init, go find and init those too

    while (modules_to_add.count() > 0) {
        it = modules_to_add.iterator();
        while (it.next()) |module| {
            debug.log("Initializing late module: {s}", .{module.value_ptr.name});
            if (module.value_ptr.init_fn != null)
                module.value_ptr.init_fn.?() catch {
                    debug.err("Error initializing module: {s}", .{module.value_ptr.name});
                    continue;
                };

            module.value_ptr.did_init = true;
            modules.putNoClobber(module.value_ptr.name, module.value_ptr.*) catch {
                debug.err("Error registering module: {s}", .{module.value_ptr.name});
            };
        }

        // done with this list now
        modules_to_add.clearAndFree();
    }
}

/// Let all modules know that initialization is done
pub fn startModules() void {
    var it = modules.iterator();
    while (it.next()) |module| {
        if (module.value_ptr.start_fn != null)
            module.value_ptr.start_fn.?();
    }
}

/// Let all modules know that things are stopping
pub fn stopModules() void {
    var it = modules.iterator();
    while (it.next()) |module| {
        if (module.value_ptr.stop_fn != null)
            module.value_ptr.stop_fn.?();
    }
}

/// Calls the tick and post-tick function of all modules
pub fn tickModules(delta_time: f32) void {
    var it = modules.iterator();
    while (it.next()) |module| {
        if (module.value_ptr.tick_fn != null)
            module.value_ptr.tick_fn.?(delta_time);
    }
}

/// Calls the fixed tick and function of all modules
pub fn fixedTickModules(fixed_delta_time: f32) void {
    var it = modules.iterator();
    while (it.next()) |module| {
        if (module.value_ptr.fixed_tick_fn != null)
            module.value_ptr.fixed_tick_fn.?(fixed_delta_time);
    }
}

/// Calls the pre-draw function of all modules. Happens before rendering
pub fn preDrawModules() void {
    var it = modules.iterator();
    while (it.next()) |module| {
        if (module.value_ptr.pre_draw_fn != null)
            module.value_ptr.pre_draw_fn.?();
    }
}

/// Calls the draw function of all modules
pub fn drawModules() void {
    var it = modules.iterator();
    while (it.next()) |module| {
        if (module.value_ptr.draw_fn != null)
            module.value_ptr.draw_fn.?();
    }
}

/// Calls the post-draw function of all modules. Happens at the end of a frame, after rendering.
pub fn postDrawModules() void {
    var it = modules.iterator();
    while (it.next()) |module| {
        if (module.value_ptr.post_draw_fn != null)
            module.value_ptr.post_draw_fn.?();
    }
}

/// Calls the cleanup function of all modules
pub fn cleanupModules() void {
    var it = modules.iterator();
    while (it.next()) |module| {
        if (module.value_ptr.cleanup_fn != null)
            module.value_ptr.cleanup_fn.?() catch {
                debug.err("Error cleaning up module: {s}", .{module.value_ptr.name});
                continue;
            };

        // reset back to initial state
        module.value_ptr.did_init = false;
    }
}
