const std = @import("std");
const math = std.math;
const ziglua = @import("ziglua");
const main = @import("../main.zig");
const debug = @import("../debug.zig");
const images = @import("../images.zig");

const Lua = ziglua.Lua;

var loaded_textures: std.AutoHashMap([*:0]const u8, u32) = undefined;
var texture_handles: std.AutoHashMap(u32, images.Image) = undefined;

// Allocator for assets
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "get_texture", .func = ziglua.wrap(getTexture) },
    };

    lua.newLib(&funcs);

    // Init everything!
    loaded_textures = std.AutoHashMap([*:0]const u8, u32).init(allocator);
    texture_handles = std.AutoHashMap(u32, images.Image).init(allocator);

    return 1;
}

fn getTexture(lua: *Lua) i32 {
    var filename_arg = lua.toString(1) catch "";

    var found: ?u32 = loaded_textures.get(filename_arg);

    if (found) |texture_handle| {
        debug.log("Assets: Found preloaded image in cache: {s} handle {d}", .{ filename_arg, texture_handle });

        lua.pushInteger(texture_handle);
        return 1;
    }

    var filename_idx: usize = 0;
    while (filename_arg[filename_idx] != 0) {
        filename_idx += 1;
    }
    const filename_len = filename_idx;

    debug.log("Assets: Loading Image: {s}...", .{filename_arg});
    var new_img: images.Image = images.loadFile(filename_arg[0..filename_len :0]) catch {
        debug.log("Assets: Error loading image asset: {s}", .{filename_arg});
        return -1;
    };

    const new_handle: u32 = texture_handles.count();
    loaded_textures.put(filename_arg, new_handle) catch {
        debug.log("Assets: Error caching loaded image handle!", .{});
        return 0;
    };

    texture_handles.put(new_handle, new_img) catch {
        debug.log("Assets: Error caching loaded image!", .{});
        return 0;
    };

    debug.log("Assets: Loaded image {s} at handle {d}", .{ filename_arg, new_handle });

    lua.pushInteger(new_handle);
    return 1;
}

pub fn getTextureFromHandle(handle: u32) ?images.Image {
    return texture_handles.get(handle);
}
