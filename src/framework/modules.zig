const std = @import("std");
const debug = @import("debug.zig");
const mem = @import("mem.zig");

const ModuleQueue = std.PriorityQueue(Module, void, compareModules);

var modules: ModuleQueue = undefined;
var needs_init: bool = true;
var initialized_modules: bool = false;

// don't put modules in the main list while iterating
var modules_to_add: ModuleQueue = undefined;

// Some easy to work with priorities
pub const Priority = struct {
    pub const first: i32 = -50;
    pub const highest: i32 = 0;
    pub const high: i32 = 50;
    pub const normal: i32 = 100;
    pub const low: i32 = 150;
    pub const lowest: i32 = 200;
    pub const last: i32 = 250;
};

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
    on_resize_fn: ?*const fn () anyerror!void = null,
    priority: i32 = 100, // lower priority runs earlier!

    // state properties
    did_init: bool = false,

    /// Runs the pre draw, draw, and post draw functions for this module. Useful when nesting modules.
    pub fn runFullRenderLifecycle(self: *const Module) void {
        if (self.pre_draw_fn != null) self.pre_draw_fn.?();
        if (self.draw_fn != null) self.draw_fn.?();
        if (self.post_draw_fn != null) self.post_draw_fn.?();
    }
};

fn compareModules(_: void, a: Module, b: Module) std.math.Order {
    return std.math.order(a.priority, b.priority);
}

pub fn deinit() void {
    debug.log("Modules system shutting down", .{});
    modules.deinit();
    modules_to_add.deinit();
}

/// Registers a module to tie it into the app lifecycle
pub fn registerModule(module: Module) !void {
    if (needs_init) {
        const allocator = mem.getAllocator();

        modules = ModuleQueue.init(allocator, {});
        modules_to_add = ModuleQueue.init(allocator, {});

        needs_init = false;
    }

    // only allow one version of a module to be registered!
    for (modules_to_add.items) |*m| {
        if (std.mem.eql(u8, module.name, m.name)) {
            debug.warning("Module {s} is already being registered! Skipping.", .{module.name});
            return;
        }
    }
    for (modules.items) |*m| {
        if (std.mem.eql(u8, module.name, m.name)) {
            debug.warning("Module {s} is already registered! Skipping.", .{module.name});
            return;
        }
    }

    try modules_to_add.add(module);
    debug.log("Registered module: {s}", .{module.name});

    // Modules registered after initialization should init right away!
    if (initialized_modules)
        initModules();
}

/// Gets a registered module
pub fn getModule(module_name: [:0]const u8) ?*Module {
    for (modules.items) |*module| {
        if (std.mem.eql(u8, module_name, module.name)) {
            return module;
        }
    }
    return null;
}

/// Initialize all the modules
pub fn initModules() void {
    // Modules could register other modules during init, so make sure to collect them all
    while (modules_to_add.items.len > 0) {
        while (modules_to_add.removeOrNull()) |module| {
            modules.add(module) catch {
                debug.err("Error adding module to initialize: {s}", .{module.name});
            };

            // initialize any new modules that were added
            for (modules.items) |*m| {
                if (m.did_init)
                    continue;

                debug.log("Initializing module: {s}", .{m.name});
                if (m.init_fn != null)
                    m.init_fn.?() catch {
                        debug.err("Error initializing module: {s}", .{m.name});
                        continue;
                    };

                m.did_init = true;
            }
        }
    }

    // let late registered modules know that we already did this
    initialized_modules = true;
}

/// Let all modules know that initialization is done
pub fn startModules() void {
    for (modules.items) |*module| {
        if (module.start_fn != null)
            module.start_fn.?();
    }
}

/// Let all modules know that things are stopping
pub fn stopModules() void {
    for (modules.items) |*module| {
        if (module.stop_fn != null)
            module.stop_fn.?();
    }
}

/// Calls the tick and post-tick function of all modules
pub fn tickModules(delta_time: f32) void {
    for (modules.items) |*module| {
        if (module.tick_fn != null)
            module.tick_fn.?(delta_time);
    }
}

/// Calls the fixed tick and function of all modules
pub fn fixedTickModules(fixed_delta_time: f32) void {
    for (modules.items) |*module| {
        if (module.fixed_tick_fn != null)
            module.fixed_tick_fn.?(fixed_delta_time);
    }
}

/// Calls the pre-draw function of all modules. Happens before rendering
pub fn preDrawModules() void {
    for (modules.items) |*module| {
        if (module.pre_draw_fn != null)
            module.pre_draw_fn.?();
    }
}

/// Calls the draw function of all modules
pub fn drawModules() void {
    for (modules.items) |*module| {
        if (module.draw_fn != null)
            module.draw_fn.?();
    }
}

/// Calls the post-draw function of all modules. Happens at the end of a frame, after rendering.
pub fn postDrawModules() void {
    for (modules.items) |*module| {
        if (module.post_draw_fn != null)
            module.post_draw_fn.?();
    }
}

/// Calls the cleanup function of all modules
pub fn cleanupModules() void {
    for (modules.items) |*module| {
        if (module.cleanup_fn != null)
            module.cleanup_fn.?() catch {
                debug.err("Error cleaning up module: {s}", .{module.name});
                continue;
            };

        // reset back to initial state
        module.did_init = false;
    }
}

/// Calls the onResize function of all modules
pub fn onResizeModules() void {
    for (modules.items) |*module| {
        if (module.on_resize_fn != null) {
            module.on_resize_fn.?() catch {
                debug.err("Error resizing module: {s}", .{module.name});
                continue;
            };
        }
    }
}
