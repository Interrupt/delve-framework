const std = @import("std");
const debug = @import("debug.zig");
const mem = @import("mem.zig");
const gfx = @import("platform/graphics.zig");

const stb_truetype = @import("stb_truetype");

var loaded_fonts: std.StringHashMap([]u8) = undefined;

pub var font_tex: gfx.Texture = undefined;

pub fn init() !void {
    loaded_fonts = std.StringHashMap([]u8).init(mem.getAllocator());
    font_tex = try loadFont("DroidSans", "assets/fonts/DroidSans.ttf");
}

pub fn loadFont(font_name: []const u8, file_name: []const u8) !gfx.Texture {
    debug.log("Loading font {s}", .{file_name});

    const file = std.fs.cwd().openFile(file_name, .{}) catch |e| {
        debug.log("{}", .{e});
        return e;
    };
    defer file.close();

    const stat = file.stat() catch |e| {
        debug.log("{}", .{e});
        return e;
    };
    debug.log("File size: {}", .{stat.size});

    const font_mem = file.reader().readAllAlloc(mem.getAllocator(), stat.size) catch |e| {
        debug.log("{}", .{e});
        return e;
    };

    loaded_fonts.put(font_name, font_mem) catch |e|
        {
        debug.log("{}", .{e});
        return e;
    };

    const font_atlas_size = 512;
    const font_atlas_scale = 2;

    const atlas_size = font_atlas_size * font_atlas_size * font_atlas_scale * font_atlas_scale;

    const atlas = mem.getAllocator().alloc(u8, atlas_size) catch |e| {
        debug.log("{}", .{e});
        return e;
    };

    var pack_context: stb_truetype.stbtt.stbtt_pack_context = undefined;
    const r0 = stb_truetype.stbtt.stbtt_PackBegin(&pack_context, @ptrCast(atlas), @intCast(font_atlas_size * font_atlas_scale), @intCast(font_atlas_size * font_atlas_scale), 0, 1, null);

    if (r0 != 0) {
        debug.log("stbtt PackBegin success!", .{});
    } else {
        debug.log("stbtt PackBegin failed!", .{});
    }

    const font_size = 200;
    const ascii_first = 32;
    const ascii_num = 95;

    const char_info = try mem.getAllocator().alloc(stb_truetype.stbtt.stbtt_packedchar, ascii_num);

    const r1 = stb_truetype.stbtt.stbtt_PackFontRange(&pack_context, @ptrCast(font_mem), 0, font_size, ascii_first, ascii_num, @ptrCast(char_info));

    if (r1 != 0) {
        debug.log("stbtt PackFontRange success!", .{});
    } else {
        debug.log("stbtt PackFontRange failed!", .{});
    }

    stb_truetype.stbtt.stbtt_PackEnd(&pack_context);

    debug.log("Number of fonts: {}", .{loaded_fonts.count()});

    return gfx.Texture.initFromBytesForFont(font_atlas_size * 2, font_atlas_size * 2, atlas);
}
