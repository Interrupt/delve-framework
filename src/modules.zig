const std = @import("std");
const debug = @import("debug.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

var modules: std.StringArrayHashMap(Module) = undefined;
var needs_init: bool = true;

pub const Module = struct {
    name: [:0]const u8,
    init_fn: ?*const fn () void = null,
    start_fn: ?*const fn () void = null,
    stop_fn: ?*const fn () void = null,
    tick_fn: ?*const fn (u64) void = null,
    draw_fn: ?*const fn () void = null,
    cleanup_fn: ?*const fn () void = null,
};

/// Registers a module to tie it into the app lifecycle
pub fn registerModule(module: Module) !void {
    if(needs_init) {
        modules = std.StringArrayHashMap(Module).init(allocator);
        needs_init = false;
    }

    // only allow one version of a module to be registered!
    try modules.putNoClobber(module.name, module);
    debug.log("Registered module: {s}", .{module.name});
}

/// Initialize all the modules
pub fn initModules() void {
    var it = modules.iterator();
    while(it.next()) |module| {
        if(module.value_ptr.init_fn != null)
            module.value_ptr.init_fn.?();
    }
}

/// Let all modules know that initialization is done
pub fn startModules() void {
    var it = modules.iterator();
    while(it.next()) |module| {
        if(module.value_ptr.start_fn != null)
            module.value_ptr.start_fn.?();
    }
}

/// Let all modules know that things are stopping
pub fn stopModules() void {
    var it = modules.iterator();
    while(it.next()) |module| {
        if(module.value_ptr.stop_fn != null)
            module.value_ptr.stop_fn.?();
    }
}

/// Calls the tick function of all modules
pub fn tickModules(tick: u64) void {
    var it = modules.iterator();
    while(it.next()) |module| {
        if(module.value_ptr.tick_fn != null)
            module.value_ptr.tick_fn.?(tick);
    }
}

/// Calls the draw function of all modules
pub fn drawModules() void {
    var it = modules.iterator();
    while(it.next()) |module| {
        if(module.value_ptr.draw_fn != null)
            module.value_ptr.draw_fn.?();
    }
}

/// Calls the cleanup function of all modules
pub fn cleanupModules() void {
    var it = modules.iterator();
    while(it.next()) |module| {
        if(module.value_ptr.cleanup_fn != null)
            module.value_ptr.cleanup_fn.?();
    }
}
