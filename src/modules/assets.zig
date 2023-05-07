const std = @import("std");
const math = std.math;
const ziglua = @import("ziglua");
const zigsdl = @import("../sdl.zig");
const main = @import("../main.zig");
const debug = @import("../debug.zig");
const gif = @import("../gif.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Lua = ziglua.Lua;

var loaded_textures: std.AutoHashMap([*:0]const u8, u32) = undefined;
var texture_handles: std.AutoHashMap(u32, gif.GifImage) = undefined;

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
    texture_handles = std.AutoHashMap(u32, gif.GifImage).init(allocator);

    return 1;
}

fn getTexture(lua: *Lua) i32 {
    var filename_arg = lua.toString(1) catch "";

    var found: ?u32 = loaded_textures.get(filename_arg);

    if (found) |texture_handle| {
        debug.log("Assets: Found preloaded Gif in cache: {s} handle {d}", .{ filename_arg, texture_handle });

        lua.pushInteger(texture_handle);
        return 1;
    }

    var filename_idx: usize = 0;
    while (filename_arg[filename_idx] != 0) {
        filename_idx += 1;
    }
    const filename_len = filename_idx;

    debug.log("Assets: Loading Gif: {s}...", .{filename_arg});
    var new_gif: gif.GifImage = gif.loadFile(filename_arg[0..filename_len :0]) catch {
        debug.log("Assets: Error loading gif asset: {s}", .{filename_arg});
        return -1;
    };

    const new_handle: u32 = texture_handles.count();
    loaded_textures.put(filename_arg, new_handle) catch {
        debug.log("Assets: Error caching loaded gif handle!", .{});
        return 0;
    };

    texture_handles.put(new_handle, new_gif) catch {
        debug.log("Assets: Error caching loaded gif!", .{});
        return 0;
    };

    debug.log("Assets: Loaded Gif {s} at handle {d}", .{ filename_arg, new_handle });

    lua.pushInteger(new_handle);
    return 1;
}

pub fn getTextureFromHandle(handle: u32) ?gif.GifImage {
    return texture_handles.get(handle);
}
