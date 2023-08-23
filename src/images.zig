const std = @import("std");
const debug = @import("debug.zig");

const stb_image = @cImport({
    // @cDefine("STBI_ONLY_GIF", "");
    @cDefine("STBI_NO_STDIO", "");
    @cInclude("stb_image.h");
});

pub const Image = struct {
    width: u32,
    height: u32,
    pitch: u32,
    channels: u8,
    raw: []u8,

    pub fn destroy(gi: *Image) void {
        stb_image.stbi_image_free(gi.raw.ptr);
    }

    pub fn create(compressed_bytes: []const u8) !Image {
        var img: Image = undefined;

        var width: c_int = undefined;
        var height: c_int = undefined;

        if (stb_image.stbi_info_from_memory(compressed_bytes.ptr, @intCast(compressed_bytes.len), &width, &height, null) == 0) {
            return error.NotPngFile;
        }

        if (width <= 0 or height <= 0) return error.NoPixels;
        img.width = @intCast(width);
        img.height = @intCast(height);

        // Not validating channel_count because it gets auto-converted to 4

        if (stb_image.stbi_is_16_bit_from_memory(compressed_bytes.ptr, @intCast(compressed_bytes.len)) != 0) {
            return error.InvalidFormat;
        }
        const bits_per_channel = 8;
        const channel_count = 4;

        // stb_image.stbi_set_flip_vertically_on_load(1);
        const image_data = stb_image.stbi_load_from_memory(compressed_bytes.ptr, @intCast(compressed_bytes.len), &width, &height, null, channel_count);

        if (image_data == null) return error.NoMem;

        img.pitch = img.width * bits_per_channel * channel_count / 8;
        img.raw = image_data[0 .. img.height * img.pitch];
        img.channels = channel_count;

        debug.log("image loaded: {d}x{d}:{d}", .{img.width, img.height, img.pitch});

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
