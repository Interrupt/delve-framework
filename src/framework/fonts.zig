const std = @import("std");
const debug = @import("debug.zig");
const math = @import("math.zig");
const mem = @import("mem.zig");
const gfx = @import("platform/graphics.zig");
const sprites = @import("graphics/sprites.zig");

const stb_truetype = @import("stb_truetype");

const Rect = @import("spatial/rect.zig").Rect;

var loaded_fonts: std.StringHashMap([]u8) = undefined;
var loaded_fonts_charinfo: std.StringHashMap([]stb_truetype.stbtt.stbtt_packedchar) = undefined;

pub var default_font_tex: gfx.Texture = undefined;

pub fn init() !void {
    loaded_fonts = std.StringHashMap([]u8).init(mem.getAllocator());
    loaded_fonts_charinfo = std.StringHashMap([]stb_truetype.stbtt.stbtt_packedchar).init(mem.getAllocator());

    default_font_tex = try loadFont("DroidSans", "assets/fonts/DroidSans.ttf", 1024, 200);
}

pub fn getCharInfo(font_name: []const u8) ?[]stb_truetype.stbtt.stbtt_packedchar {
    return loaded_fonts_charinfo.get(font_name);
}

pub const CharQuad = struct {
    rect: Rect,
    tex_region: sprites.TextureRegion,
};

pub fn getCharQuad(font_name: []const u8, char_index: usize, x_pos: *f32, y_pos: *f32) CharQuad {
    const found_char_info = getCharInfo(font_name);

    var aligned_quad: stb_truetype.stbtt.stbtt_aligned_quad = undefined;

    var char_quad: CharQuad = undefined;

    if (found_char_info) |char_info| {
        stb_truetype.stbtt.stbtt_GetPackedQuad(@ptrCast(char_info), 1024, 1024, @intCast(char_index), @ptrCast(x_pos), @ptrCast(y_pos), &aligned_quad, 1);

        debug.log("{}", .{aligned_quad});

        // tex region
        char_quad.tex_region.u = aligned_quad.s0;
        char_quad.tex_region.v = aligned_quad.t0;
        char_quad.tex_region.u_2 = aligned_quad.s1;
        char_quad.tex_region.v_2 = aligned_quad.t1;

        // pos rect
        char_quad.rect.x = aligned_quad.x0;
        char_quad.rect.y = -aligned_quad.y0;
        char_quad.rect.width = aligned_quad.x1 - aligned_quad.x0;
        char_quad.rect.height = aligned_quad.y1 - aligned_quad.y0;

        // adjust to line height
        char_quad.rect.y -= char_quad.rect.height;
    }

    return char_quad;
}

pub fn loadFont(font_name: []const u8, file_name: []const u8, tex_size: u32, font_size: f32) !gfx.Texture {
    debug.log("Loading font {s}", .{file_name});

    const file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    const stat = try file.stat();
    debug.log("Font file size: {}", .{stat.size});

    const font_mem = try file.reader().readAllAlloc(mem.getAllocator(), stat.size);
    try loaded_fonts.put(font_name, font_mem);

    // set some sizes for loading
    const font_atlas_size = tex_size;
    const atlas_size = font_atlas_size * font_atlas_size;

    const atlas_img = try mem.getAllocator().alloc(u8, atlas_size);

    var pack_context: stb_truetype.stbtt.stbtt_pack_context = undefined;
    const r0 = stb_truetype.stbtt.stbtt_PackBegin(&pack_context, @ptrCast(atlas_img), @intCast(font_atlas_size), @intCast(font_atlas_size), 0, 1, null);

    if (r0 != 0) {
        debug.log("stbtt PackBegin success!", .{});
    } else {
        debug.log("stbtt PackBegin failed!", .{});
    }

    const ascii_first = 32;
    const ascii_num = 95;

    const char_info = try mem.getAllocator().alloc(stb_truetype.stbtt.stbtt_packedchar, ascii_num);

    const r1 = stb_truetype.stbtt.stbtt_PackFontRange(&pack_context, @ptrCast(font_mem), 0, font_size, ascii_first, ascii_num, @ptrCast(char_info));

    if (r1 != 0) {
        debug.log("stbtt PackFontRange success!", .{});
    } else {
        debug.log("stbtt PackFontRange failed!", .{});
    }

    // Cache character info!
    try loaded_fonts_charinfo.put(font_name, char_info);

    stb_truetype.stbtt.stbtt_PackEnd(&pack_context);

    debug.log("Number of cached fonts: {}", .{loaded_fonts.count()});

    // Create and return a texture based on our atlas bytes
    return gfx.Texture.initFromBytesForFont(font_atlas_size, font_atlas_size, atlas_img);
}
