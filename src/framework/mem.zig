const std = @import("std");

pub var main_allocator: std.mem.Allocator = undefined;

var did_init: bool = false;

pub fn init(allocator: std.mem.Allocator) void {
    main_allocator = allocator;
    did_init = true;
}

pub fn getAllocator() std.mem.Allocator {
    if (!did_init) {
        // We can at least warn people that things were not initialized properly
        std.debug.print("\nERROR: Did not call delve.init before other Delve Framework functions!\n", .{});
    }

    return main_allocator;
}
