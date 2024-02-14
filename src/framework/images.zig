const std = @import("std");
const debug = @import("debug.zig");
const zstbi = @import("zstbi");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub const Image = zstbi.Image;

pub fn loadFile(file_path: [:0]const u8) !Image {
    const file = try std.fs.cwd().openFile(
        file_path,
        .{}, // mode is read only by default
    );
    defer file.close();

    const file_size = (try file.stat()).size;

    const contents = try file.reader().readAllAlloc(allocator, file_size);
    defer allocator.free(contents);

    return loadBytes(contents);
}

pub fn loadBytes(image_bytes: []const u8) !Image {
    zstbi.init(allocator);
    return Image.loadFromMemory(image_bytes, 0);
}
