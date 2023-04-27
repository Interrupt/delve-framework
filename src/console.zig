const std = @import("std");
const text_module = @import("modules/text.zig");

var visible = true;
var num_to_show: u32 = 10;

// Manage our own memory!
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

// List of log history
const log_history = std.ArrayList([:0]const u8);
var log_history_list: std.ArrayListAligned([:0]const u8, null) = undefined;

pub fn init() void {
    log_history_list = log_history.init(allocator);

    logLine("Brass Emulator Starting");
    logLine("Hello Zig!");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
    logLine("This is a fake log line.");
}

pub fn deinit() void {
    log_history_list.deinit();
    _ = gpa.deinit();
}

pub fn logLine(text: [:0]const u8) void {
    log_history_list.append(text) catch {
    };

    std.debug.print("Logging: {s}\n", .{text});
}

pub fn clear() void {
    log_history_list.clearRetainingCapacity();
}

pub fn updateAndDraw() void {
    if(!visible)
        return;

    var y_pos: i32 = 0;
    var count: u32 = 0;
    for(log_history_list.items) |line| {
        text_module.drawText(line, 0, y_pos, 1);
        y_pos += 8;
        count += 1;

        if(count >= num_to_show)
            break;
    }

    text_module.drawText("> ", 0, y_pos, 1);
}

pub fn setVisible(is_visable: bool) void {
    visible = is_visable;
}
