const std = @import("std");
const debug = @import("debug.zig");
const zstbi = @import("zstbi");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub const Image = zstbi.Image;

pub fn init() void {
    zstbi.init(allocator);
}

pub fn deinit() void {
    zstbi.deinit();
}

pub fn loadFile(file_path: [:0]const u8) !Image {
    const file = try std.fs.cwd().openFile(
        file_path,
        .{}, // mode is read only by default
    );
    defer file.close();

    const file_stat = try file.stat();
    const file_size: usize = @as(usize, @intCast(file_stat.size));

    const contents = try file.reader().readAllAlloc(allocator, file_size);
    defer allocator.free(contents);

    return loadBytes(contents);
}

pub fn loadBytes(image_bytes: []const u8) !Image {
    return Image.loadFromMemory(image_bytes, 0);
}
