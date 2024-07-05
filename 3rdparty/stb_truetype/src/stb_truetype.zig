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

    const font_mem = &[_]u8{0} ** 128;

    var pack_context: stbtt.stbtt_pack_context = undefined;
    const r0 = stbtt.stbtt_PackBegin(&pack_context, @ptrCast(@constCast(font_mem)), 32, 32, 0, 1, null);

    try testing.expect(r0 == 0);
}
