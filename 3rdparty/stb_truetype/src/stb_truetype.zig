const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

// For now, just make an external import that people can pull and use
pub const stbtt = @cImport({
    @cInclude("stb_truetype.h");
    @cInclude("stb_rect_pack.h");
});

test "stb_truetype test import" {
    var char_info_type: stbtt.stbtt_packedchar = .{};
    char_info_type.xoff = 1.0;

    try testing.expect(char_info_type.xoff == 1.0);
}
