const std = @import("std");
const yaml = @import("zigyaml");
const mem = @import("../mem.zig");
const debug = @import("../debug.zig");

pub fn loadFromYaml(file_path: []const u8) !void {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const allocator = mem.getAllocator();

    const source = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(source);

    debug.log("{s}", .{source});

    var untyped_yaml = yaml.Yaml.load(allocator, source) catch |e| {
        debug.log("Yaml loading error! {any}", .{e});
        return;
    };
    defer untyped_yaml.deinit();

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
