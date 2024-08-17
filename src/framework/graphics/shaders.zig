const std = @import("std");
const yaml = @import("zigyaml");
const mem = @import("mem.zig");

pub fn loadShaderFromYaml(filename: []const u8) !void {
    try testYaml();
}

pub const YamlTest = struct {
    testentry: []const u8,
};

pub fn testYaml() !void {
    var untyped = yaml.Yaml.load(mem.getAllocator(), "testentry: chad 2") catch |e| {
        debug.log("Yaml loading error! {any}", .{e});
        return;
    };
    defer untyped.deinit();

    // var untyped = try yaml_parsed.load(YamlTest);
    // defer untyped.deinit();

    debug.log("Yaml: {s}", .{untyped.docs.items[0].map.get("testentry").?.string});
}
