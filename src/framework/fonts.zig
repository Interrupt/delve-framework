const std = @import("std");
const colors = @import("colors.zig");
const debug = @import("debug.zig");
const math = @import("math.zig");
const mem = @import("mem.zig");
const gfx = @import("platform/graphics.zig");
const images = @import("images.zig");
const sprites = @import("graphics/sprites.zig");
const batcher = @import("graphics/batcher.zig");

const stb_truetype = @import("stb_truetype");

const Rect = @import("spatial/rect.zig").Rect;

pub const LoadedFont = struct {
    font_name: []const u8,
    font_mem: []const u8,
    tex_size: u32, // eg: 1024
    font_size: f32, // eg: 200
    texture: gfx.Texture,
    char_info: []stb_truetype.stbtt.stbtt_packedchar,
};

pub const CharQuad = struct {
    rect: Rect,
    tex_region: sprites.TextureRegion,
};

var loaded_fonts: std.StringHashMap(LoadedFont) = undefined;

pub fn init() !void {
    loaded_fonts = std.StringHashMap(LoadedFont).init(mem.getAllocator());
}

pub fn deinit() void {
    var allocator = mem.getAllocator();

    // cleanup fonts
    var it = loaded_fonts.valueIterator();
    while (it.next()) |font_ptr| {
        allocator.free(font_ptr.font_mem);
        allocator.free(font_ptr.char_info);
        font_ptr.texture.destroy();
    }

    loaded_fonts.deinit();
}

// Grab a single character from a font, updating cursor position
pub fn getCharQuad(font: *LoadedFont, char_index: usize, x_pos: *f32, y_pos: *f32) CharQuad {
    var aligned_quad: stb_truetype.stbtt.stbtt_aligned_quad = undefined;

    stb_truetype.stbtt.stbtt_GetPackedQuad(@ptrCast(font.char_info), @intCast(font.tex_size), @intCast(font.tex_size), @intCast(char_index), @ptrCast(x_pos), @ptrCast(y_pos), &aligned_quad, 1);

    // debug.log("{}", .{aligned_quad});

    var char_quad: CharQuad = .{
        .tex_region = sprites.TextureRegion.default(),
        .rect = Rect.fromSize(math.Vec2.new(1.0, 1.0)),
    };

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

    return char_quad;
}

pub fn getLoadedFont(font_name: []const u8) ?*LoadedFont {
    return loaded_fonts.getPtr(font_name);
}

const LoadFontErrors = error{
    ErrorPacking,
};

// Load and cache a font to be used later
pub fn loadFont(font_name: []const u8, file_name: []const u8, tex_size: u32, font_size: f32) !*LoadedFont {
    var allocator = mem.getAllocator();

    debug.log("Loading font {s}", .{file_name});
    const file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    const stat = try file.stat();
    const font_mem = try file.reader().readAllAlloc(allocator, @intCast(stat.size));

    // set some sizes for loading
    const font_atlas_size = tex_size;
    const atlas_size = font_atlas_size * font_atlas_size;

    const atlas_img = try allocator.alloc(u8, atlas_size);
    const atlas_img_expanded = try allocator.alloc(u8, atlas_size * 4);

    // will be done with these after the texture is created
    defer allocator.free(atlas_img);
    defer allocator.free(atlas_img_expanded);

    var pack_context: stb_truetype.stbtt.stbtt_pack_context = undefined;
    const r0 = stb_truetype.stbtt.stbtt_PackBegin(&pack_context, @ptrCast(atlas_img), @intCast(font_atlas_size), @intCast(font_atlas_size), 0, 1, null);

    if (r0 == 0) {
        debug.log("error loading font: stbtt_PackBegin failed!", .{});
        return LoadFontErrors.ErrorPacking;
    }

    const ascii_first = 32;
    const ascii_num = 95;

    const char_info = try mem.getAllocator().alloc(stb_truetype.stbtt.stbtt_packedchar, ascii_num);

    const r1 = stb_truetype.stbtt.stbtt_PackFontRange(&pack_context, @ptrCast(font_mem), 0, font_size, ascii_first, ascii_num, @ptrCast(char_info));

    if (r1 == 0) {
        debug.log("error loading font: stbtt_PackFontRange failed!", .{});
        return LoadFontErrors.ErrorPacking;
    }

    stb_truetype.stbtt.stbtt_PackEnd(&pack_context);

    // expand the image to add the other three channels in the image bytes
    var idx: u32 = 0;
    for (atlas_img) |v| {
        atlas_img_expanded[idx] = v;
        atlas_img_expanded[idx + 1] = v;
        atlas_img_expanded[idx + 2] = v;
        atlas_img_expanded[idx + 3] = v;
        idx += 4;
    }

    // debug.log("Creating font texture, len: {d}", .{idx});

    const loaded_font: LoadedFont = .{
        .font_name = font_name,
        .font_mem = font_mem,
        .tex_size = tex_size,
        .font_size = font_size,
        .texture = gfx.Texture.initFromBytes(font_atlas_size, font_atlas_size, atlas_img_expanded),
        .char_info = char_info,
    };

    try loaded_fonts.put(font_name, loaded_font);
    return loaded_fonts.getPtr(font_name).?;
}

// Adds a string to an existing sprite batch
pub fn addStringToSpriteBatch(font: *LoadedFont, sprite_batch: *batcher.SpriteBatcher, string: []const u8, x_pos: *f32, y_pos: *f32, scale: f32, color: colors.Color) void {
    addStringToSpriteBatchWithKerning(font, sprite_batch, string, x_pos, y_pos, 0, 0, scale, color);
}

pub fn addStringToSpriteBatchWithKerning(font: *LoadedFont, sprite_batch: *batcher.SpriteBatcher, string: []const u8, x_pos: *f32, y_pos: *f32, line_height_mod: f32, kerning_mod: f32, scale: f32, color: colors.Color) void {
    sprite_batch.useTexture(font.texture);

    const orig_x: f32 = x_pos.*;

    for (string) |char| {
        if (char == '\n') {
            x_pos.* = orig_x;
            y_pos.* += font.font_size + line_height_mod;
            continue;
        }

        const char_quad_t = getCharQuad(font, char - 32, x_pos, y_pos);
        sprite_batch.addRectangle(char_quad_t.rect.scale(scale), char_quad_t.tex_region, color);
        x_pos.* += kerning_mod;
    }

    x_pos.* = orig_x;
    y_pos.* += font.font_size + line_height_mod;
}

// Returns the rectangle of where and how big this string would be
pub fn getStringBounds(font: *LoadedFont, string: []const u8, x: f32, y: f32, scale: f32) Rect {
    return getStringBoundsWithKerning(font, string, x, y, scale, 0, 0);
}

pub fn getStringBoundsWithKerning(font: *LoadedFont, string: []const u8, x: f32, y: f32, scale: f32, line_height_mod: f32, kerning_mod: f32) Rect {
    var x_pos: f32 = x;
    var y_pos: f32 = y;

    const orig_x: f32 = x_pos;

    var set_min: bool = false;
    var rect_min: math.Vec2 = math.Vec2.zero;

    var set_max: bool = false;
    var rect_max: math.Vec2 = math.Vec2.zero;

    for (string) |char| {
        if (char == '\n') {
            x_pos = orig_x;
            y_pos += font.font_size + line_height_mod;
            continue;
        }

        const char_quad_t = getCharQuad(font, char - 32, &x_pos, &y_pos);
        const rect = char_quad_t.rect.scale(scale);
        x_pos += kerning_mod;

        const bot_left = rect.getBottomLeft();
        const top_right = rect.getTopRight();

        if (set_min) {
            if (rect_min.x > bot_left.x)
                rect_min.x = bot_left.x;
            if (rect_min.y > bot_left.y)
                rect_min.y = bot_left.y;
        } else {
            rect_min = bot_left;
            set_min = true;
        }

        if (set_max) {
            if (rect_max.x < top_right.x)
                rect_max.x = top_right.x;
            if (rect_max.y < top_right.y)
                rect_max.y = top_right.y;
        } else {
            rect_max = top_right;
            set_max = true;
        }
    }

    return Rect.new(rect_min, rect_max.sub(rect_min));
}
