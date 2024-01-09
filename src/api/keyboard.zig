const std = @import("std");
const debug = @import("../debug.zig");
const ziglua = @import("ziglua");
const input = @import("../platform/input.zig");

pub fn key(key_idx: usize) bool {
   return input.isKeyPressed(@enumFromInt(key_idx));
}
