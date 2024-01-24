const std = @import("std");
const debug = @import("debug.zig");

const stb_image = @cImport({
    @cDefine("STBI_NO_STDIO", "");
    @cInclude("stb_image.h");
});

pub const Image = struct {
    width: u32,
    height: u32,
    pitch: u32,
    channels: u8,
    raw: []u8,

    pub fn destroy(self: *Image) void {
        stb_image.stbi_image_free(self.raw.ptr);
    }

    pub fn create(compressed_bytes: []const u8) !Image {
        var img: Image = undefined;

        var width: c_int = undefined;
        var height: c_int = undefined;
        const channel_count = 4;

        const image_data = stb_image.stbi_load_from_memory(compressed_bytes.ptr, @intCast(compressed_bytes.len), &width, &height, null, channel_count);

        if (image_data == null) return error.NoMem;

        img.width = @intCast(width);
        img.height = @intCast(height);
        img.channels = channel_count;
        img.pitch = img.width * channel_count;
        img.raw = image_data[0 .. img.height * img.pitch];

        debug.log("image loaded: {d}x{d}:{d}", .{img.width, img.height, img.channels});

        return img;
    }
};

pub fn loadFile(file_path: [:0]const u8) !Image {
    const file = try std.fs.cwd().openFile(
        file_path,
        .{}, // mode is read only by default
    );
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    const file_size = (try file.stat()).size;

    const contents = try file.reader().readAllAlloc(allocator, file_size);
    defer allocator.free(contents);

    return Image.create(contents);
}

pub fn loadBytes(image_bytes: []const u8) !Image {
    return Image.create(image_bytes);
}
