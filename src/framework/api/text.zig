const std = @import("std");
const math = std.math;
const ziglua = @import("ziglua");
const app = @import("../app.zig");
const colors = @import("../colors.zig");
const images = @import("../images.zig");
const debug = @import("../debug.zig");
const gfx = @import("../platform/graphics.zig");

pub fn draw(text_string: [*:0]const u8, x: i32, y: i32, color: u32) void {
    var x_offset: i32 = 0;
    var y_offset: i32 = 0;

    var idx: u32 = 0;

    // Draw until hitting the sentinel
    while (true) {
        var char: u8 = text_string[idx];
        idx += 1;

        if (char == 0)
            break;

        if (char == '\n') {
            x_offset = 0;
            y_offset += 8;
            continue;
        }

        drawGlyph(char, x + x_offset, y + y_offset, color);
        x_offset += 8;
    }
}

pub fn draw_wrapped(text_string: [*:0]const u8, x: i32, y: i32, width: i32, color: u32) void {
    var x_offset: i32 = 0;
    var y_offset: i32 = 0;

    var idx: u32 = 0;

    // Draw until hitting the sentinel
    while (true) {
        var char: u8 = text_string[idx];
        idx += 1;

        if (char == 0)
            break;

        if (char == '\n') {
            x_offset = 0;
            y_offset += 8;
            continue;
        }

        // Wrap the text if we've gone over the width bounds
        if (x_offset + 8 > @divFloor(width, 2)) {
            x_offset = 0;
            y_offset += 8;
        }

        drawGlyph(char, x + x_offset, y + y_offset, color);
        x_offset += 8;
    }
}

pub fn getTextHeight(text_string: [*:0]const u8, width: i32) i32 {
    var x_offset: i32 = 0;
    var y_offset: i32 = 0;

    var idx: u32 = 0;

    // Draw until hitting the sentinel
    while (true) {
        var char: u8 = text_string[idx];
        idx += 1;

        if (char == 0)
            break;

        if (char == '\n') {
            x_offset = 0;
            y_offset += 8;
            continue;
        }

        // Wrap the text if we've gone over the width bounds
        if (x_offset + 8 > @divFloor(width, 2)) {
            x_offset = 0;
            y_offset += 8;
        }

        // Would have drawn a glyph, update size!
        x_offset += 8;
    }

    return y_offset + 8;
}

pub fn drawGlyph(char: u8, x: i32, y: i32, color: u32) void {
    const pal_color = colorFromPalette(color);

    // TODO: This should blit part of a texture to the screen, not use the debug text stuff!
    gfx.setDebugTextScale(1.0, 1.0);
    gfx.setDebugTextColor(pal_color);
    gfx.drawDebugTextChar(@floatFromInt(x), @floatFromInt(y), char);
}

fn colorFromPalette(pal_color: u32) colors.Color {
    return colors.getColorFromPalette(pal_color);
}
