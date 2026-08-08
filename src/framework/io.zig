const std = @import("std");
const Io = std.Io;

var io: Io = undefined;

pub fn init(in_io: std.Io) void {
    io = in_io;
}

pub fn getIo() Io {
    return io;
}
