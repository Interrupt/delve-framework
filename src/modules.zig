const std = @import("std");
const debug = @import("debug.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

var modules: []Module = undefined;
var num_modules: u32 = 0;

pub const Module = struct {
    name: [:0]const u8,
    init_fn: ?*const fn () void = null,
    start_fn: ?*const fn () void = null,
    stop_fn: ?*const fn () void = null,
    tick_fn: ?*const fn (u64) void = null,
    draw_fn: ?*const fn () void = null,
    cleanup_fn: ?*const fn () void = null,
};

pub fn registerModule(module: Module) !void {
    if(num_modules == 0)
        modules = try allocator.alloc(Module, 64);

    modules[num_modules] = module;
    num_modules += 1;

    debug.log("Registered module: {s}", .{module.name});
}

pub fn getModules() []Module {
    return modules[0..num_modules];
}

pub fn initModules() void {
    for(getModules()) |module| {
        if(module.init_fn != null)
            module.init_fn.?();
    }
}

pub fn startModules() void {
    for(getModules()) |module| {
        if(module.start_fn != null)
            module.start_fn.?();
    }
}

pub fn stopModules() void {
    for(getModules()) |module| {
        if(module.stop_fn != null)
            module.stop_fn.?();
    }
}

pub fn tickModules(tick: u64) void {
    for(getModules()) |module| {
        if(module.tick_fn != null)
            module.tick_fn.?(tick);
    }
}

pub fn drawModules() void {
    for(getModules()) |module| {
        if(module.draw_fn != null)
            module.draw_fn.?();
    }
}

pub fn cleanupModules() void {
    for(getModules()) |module| {
        if(module.cleanup_fn != null)
            module.cleanup_fn.?();
    }
}
