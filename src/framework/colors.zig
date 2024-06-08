const std = @import("std");
const debug = @import("debug.zig");
const images = @import("images.zig");
const graphics = @import("platform/graphics.zig");

const builtin_palette = @embedFile("static/palette.gif");

/// The global color palette
pub var palette: [64]Color = [_]Color{Color{}} ** 64;

pub const Color = struct {
    r: f32 = 1.0,
    g: f32 = 1.0,
    b: f32 = 1.0,
    a: f32 = 1.0,

    /// Make a new color
    pub fn new(r: f32, g: f32, b: f32, a: f32) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Make a new color, using bytes
    pub fn newBytes(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = @as(f32, @floatFromInt(r)) / 255.0, .g = @as(f32, @floatFromInt(g)) / 255.0, .b = @as(f32, @floatFromInt(b)) / 255.0, .a = @as(f32, @floatFromInt(a)) / 255.0 };
    }

    /// Turn an array of floats into a color
    pub fn fromArray(val: [4]f32) Color {
        return Color{ .r = val[0], .g = val[1], .b = val[2], .a = val[3] };
    }

    /// Convert this color to a packed int
    pub fn toInt(self: Color) u32 {
        var c: u32 = 0;
        c |= @intFromFloat(self.r * 0x000000FF);
        c |= @intFromFloat(self.g * 0x0000FF00);
        c |= @intFromFloat(self.b * 0x00FF0000);
        c |= @intFromFloat(self.a * 0xFF000000);
        return c;
    }

    /// Get a color from a packed int
    pub fn fromInt(i_color: u32) Color {
        const r_byte: u32 = (i_color & 0x000000FF);
        const g_byte: u32 = (i_color & 0x0000FF00) >> 8;
        const b_byte: u32 = (i_color & 0x00FF0000) >> 16;
        const a_byte: u32 = (i_color & 0xFF000000) >> 24;

        const r: f32 = @as(f32, @floatFromInt(r_byte)) / 255.0;
        const g: f32 = @as(f32, @floatFromInt(g_byte)) / 255.0;
        const b: f32 = @as(f32, @floatFromInt(b_byte)) / 255.0;
        const a: f32 = @as(f32, @floatFromInt(a_byte)) / 255.0;

        return Color.new(r, g, b, a);
    }

    /// Output an array of floats from the channels
    pub fn toArray(self: Color) [4]f32 {
        return [_]f32{ self.r, self.g, self.b, self.a };
    }

    /// Get a color multiplied by these colors
    pub fn mul(left: *const Color, right: Color) Color {
        return Color{
            .r = left.r * right.r,
            .g = left.g * right.g,
            .b = left.b * right.b,
            .a = left.a * right.a,
        };
    }

    /// Clamps values back to the 0.0 - 1.0 range
    pub fn clamp(self: *const Color) Color {
        return Color{
            .r = std.math.clamp(self.r, 0.0, 1.0),
            .g = std.math.clamp(self.g, 0.0, 1.0),
            .b = std.math.clamp(self.b, 0.0, 1.0),
            .a = std.math.clamp(self.a, 0.0, 1.0),
        };
    }

    /// Scale a color by a float value, ignoring alpha
    pub fn scale(left: *const Color, scl: f32) Color {
        return Color{
            .r = left.r * scl,
            .g = left.g * scl,
            .b = left.b * scl,
            .a = left.a,
        };
    }
};

// Preset colors!
pub const transparent: Color = Color.new(0.0, 0.0, 0.0, 0.0);
pub const white: Color = Color.new(1.0, 1.0, 1.0, 1.0);
pub const black: Color = Color.new(0.0, 0.0, 0.0, 1.0);
pub const grey: Color = Color.new(0.5, 0.5, 0.5, 1.0);
pub const dark_grey: Color = Color.new(0.25, 0.25, 0.25, 1.0);
pub const light_grey: Color = Color.new(0.75, 0.75, 0.75, 1.0);
pub const red: Color = Color.new(1.0, 0.0, 0.0, 1.0);
pub const green: Color = Color.new(0.0, 1.0, 0.0, 1.0);
pub const blue: Color = Color.new(0.0, 0.0, 1.0, 1.0);
pub const cyan: Color = Color.newBytes(0, 183, 235, 255);
pub const magenta: Color = Color.newBytes(255, 0, 255, 255);
pub const yellow: Color = Color.newBytes(255, 246, 0, 255);
pub const orange: Color = Color.newBytes(255, 79, 0, 255);
pub const purple: Color = Color.newBytes(160, 32, 240, 255);
pub const brown: Color = Color.newBytes(150, 75, 0, 255);
pub const tan: Color = Color.newBytes(210, 180, 140, 255);
pub const olive: Color = Color.newBytes(128, 128, 0, 255);
pub const pink: Color = Color.newBytes(231, 84, 128, 255);
pub const navy: Color = Color.newBytes(0, 0, 128, 255);
pub const maroon: Color = Color.newBytes(130, 0, 0, 255);
pub const forest_green: Color = Color.newBytes(34, 139, 34, 255);

// preset colors for the examples
pub const examples_bg_dark: Color = Color.newBytes(22, 22, 35, 255);
pub const examples_bg_light: Color = Color.newBytes(200, 200, 200, 255);

pub fn init() !void {
    palette = try loadBuiltinPalette();
}

pub fn deinit() void {}

/// Sets the palette using the statically included default
pub fn loadBuiltinPalette() ![64]Color {
    var palette_img = try images.loadBytes(builtin_palette);
    defer palette_img.deinit();

    return fillPalette(palette_img);
}

/// Sets the palette from a file
pub fn loadPaletteFromFile(filename: [:0]const u8) ![64]Color {
    var palette_img = try images.loadFile(filename);
    defer palette_img.deinit();

    return fillPalette(palette_img);
}

/// Returns a palette from colors in this image
pub fn fillPalette(palette_img: images.Image) [64]Color {
    var new_palette: [64]Color = [_]Color{Color{}} ** 64;

    // Load the colors into the palette
    for (0..palette_img.width * palette_img.height) |i| {
        const color_idx = i * palette_img.num_components;

        if (i >= new_palette.len)
            break;

        if (color_idx >= palette_img.height * palette_img.bytes_per_row)
            break;

        const r = palette_img.data[color_idx];
        const g = palette_img.data[color_idx + 1];
        const b = palette_img.data[color_idx + 2];

        const c = graphics.Color{
            .r = @as(f32, @floatFromInt(r)) / 256.0,
            .g = @as(f32, @floatFromInt(g)) / 256.0,
            .b = @as(f32, @floatFromInt(b)) / 256.0,
        };

        new_palette[i] = c;
    }

    return new_palette;
}

/// Returns a color in the palette at the given index
pub fn getColorFromPalette(pal_idx: u32) Color {
    if (pal_idx > palette.len)
        return Color{};

    return palette[pal_idx];
}
