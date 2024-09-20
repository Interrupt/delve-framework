const std = @import("std");

// Hack: keep our GeneralPurposeAllocator internal to the delve framework, as quitting on OSX
// seems to quit immediately after Sokol cleans up.
pub var default_gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 16 }){};

pub var main_allocator: std.mem.Allocator = undefined;

var did_init: bool = false;

pub fn init(allocator: std.mem.Allocator) void {
    main_allocator = allocator;
    did_init = true;
}

pub fn deinit() void {
    // Can check for memory leaks if we use the default GPA
    _ = default_gpa.deinit();
}

pub fn getAllocator() std.mem.Allocator {
    if (!did_init) {
        // We can at least warn people that things were not initialized properly
        std.debug.print("\nERROR: Did not call delve.init before other Delve Framework functions!\n", .{});
    }

    return main_allocator;
}

pub fn createDefaultAllocator() std.mem.Allocator {
    return default_gpa.allocator();
}
