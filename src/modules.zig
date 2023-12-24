const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

var modules: []Module = undefined;
var num_modules: u32 = 0;

pub const Module = struct {
    init_fn: *const fn () void,
    tick_fn: *const fn (u64) void,
    draw_fn: *const fn () void,
    cleanup_fn: *const fn () void,
};

pub fn registerModule(module: Module) !void {
    if(num_modules == 0)
        modules = try allocator.alloc(Module, 64);

    modules[num_modules] = module;
    num_modules += 1;
}

pub fn getModules() []Module {
    return modules[0..num_modules];
}

pub fn initModules() void {
    for(getModules()) |module| {
        module.init_fn();
    }
}

pub fn tickModules(tick: u64) void {
    for(getModules()) |module| {
        module.tick_fn(tick);
    }
}

pub fn drawModules() void {
    for(getModules()) |module| {
        module.draw_fn();
    }
}

pub fn cleanupModules() void {
    for(getModules()) |module| {
        module.cleanup_fn();
    }
}
