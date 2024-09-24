const std = @import("std");
const math = std.math;
const ziglua = @import("ziglua");
const debug = @import("../debug.zig");
const images = @import("../images.zig");
const graphics = @import("../platform/graphics.zig");

var loaded_textures: std.AutoHashMap([*:0]const u8, u32) = undefined;
var image_handles: std.AutoHashMap(u32, images.Image) = undefined;
var texture_handles: std.AutoHashMap(u32, graphics.Texture) = undefined;

// Allocator for assets
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

// TODO: Move the guts of this to a subsystem!

// called automatically when the library is binded
pub fn libInit() !void {
    debug.log("Assets: initializing", .{});
    loaded_textures = std.AutoHashMap([*:0]const u8, u32).init(allocator);
    image_handles = std.AutoHashMap(u32, images.Image).init(allocator);
    texture_handles = std.AutoHashMap(u32, graphics.Texture).init(allocator);
}

// return a texture handle or -1 if an error occurs
pub fn get_texture(filename: [*:0]const u8) i64 {
    const found: ?u32 = loaded_textures.get(filename);

    if (found) |texture_handle| {
        debug.log("Assets: Found preloaded image in cache: {s} handle {d}", .{ filename, texture_handle });
        return texture_handle;
    }

    var filename_idx: usize = 0;
    while (filename[filename_idx] != 0) {
        filename_idx += 1;
    }
    const filename_len = filename_idx;

    debug.log("Assets: Loading Image: {s}...", .{filename});
    const new_img: images.Image = images.loadFile(filename[0..filename_len :0]) catch {
        debug.log("Assets: Error loading image asset: {s}", .{filename});
        return -1;
    };

    const new_handle: u32 = texture_handles.count();
    loaded_textures.put(filename, new_handle) catch {
        debug.log("Assets: Error caching loaded image handle!", .{});
        return -1;
    };

    image_handles.put(new_handle, new_img) catch {
        debug.log("Assets: Error caching loaded image!", .{});
        return -1;
    };

    const texture = graphics.Texture.init(new_img);
    texture_handles.put(new_handle, texture) catch {
        debug.log("Assets: Error caching loaded texture!", .{});
        return -1;
    };

    debug.log("Assets: Loaded image {s} at handle {d}", .{ filename, new_handle });
    return new_handle;
}

pub fn _getImageFromHandle(handle: i64) ?images.Image {
    return image_handles.get(@intCast(handle));
}

pub fn _getTextureFromHandle(handle: i64) ?graphics.Texture {
    return texture_handles.get(@intCast(handle));
}
