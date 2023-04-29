const std = @import("std");
const zigsdl = @import("sdl.zig");
const text_module = @import("modules/text.zig");
const draw_module = @import("modules/draw.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

var console_visible = true;
var console_num_to_show: u32 = 5;

// Manage our own memory!
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

// Lists of log history and command history
const text_array = std.ArrayList([:0]const u8);
var log_history_list: std.ArrayListAligned([:0]const u8, null) = undefined;
var cmd_history_list: std.ArrayListAligned([:0]const u8, null) = undefined;

// Our next pending command
var cmd_buf: [512]u8 = undefined;
var cmd_fbs = std.io.fixedBufferStream(&cmd_buf);
const cmd_stream = cmd_fbs.writer();

const log_history_max_len = 100;

pub fn init() void {
    log_history_list = text_array.init(allocator);
    cmd_history_list = text_array.init(allocator);

    var log_line: u32 = 0;
    logLine("Brass Emulator Starting", .{});

    logLine("Hello Zig! {d}", .{log_line});
    log_line += 1;
    logLine("Hello Zig! {d}", .{log_line});
    log_line += 1;
    logLine("Hello Zig! {d}", .{log_line});
    log_line += 1;
    logLine("Hello Zig! {d}", .{log_line});
    log_line += 1;
    logLine("Hello Zig! {d}", .{log_line});
    log_line += 1;
    logLine("Hello Zig! {d}", .{log_line});
    log_line += 1;
    logLine("Hello Zig! {d}", .{log_line});
    log_line += 1;
}

pub fn deinit() void {
    for(log_history_list.items) |line| { allocator.free(line); }
    log_history_list.deinit();

    for(cmd_history_list.items) |line| { allocator.free(line); }
    cmd_history_list.deinit();
    _ = gpa.deinit();
}

pub fn logLine(comptime fmt: []const u8, args: anytype) void {
    // Make an output stream for the console log line formatting
    var buf: [256:0]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const stream = fbs.writer();

    stream.print(fmt, args) catch { return; };
    stream.print("\x00", .{}) catch { return; };

    // Log to std out
    const written = fbs.getWritten();
    std.debug.print("{s}\n", .{written});

    // Alloc some memory to keep a copy of this log line in the history
    const memory = allocator.alloc(u8, written.len) catch { return; };
    std.mem.copy(u8, memory, written);


    // Now append the log line to the history
    log_history_list.append(memory[0..memory.len-1 :0]) catch |err| {
        std.debug.print("Log append error: {}\n", .{err});
    };


    // Compact the history if growing out of bounds
    if(log_history_list.items.len <= log_history_max_len)
        return;

    const removed = log_history_list.orderedRemove(0);
    allocator.free(removed);
}

pub fn drawConsole() void {
    if(!console_visible)
        return;

    const height_pixels = @intCast(i32, (console_num_to_show + 1) * 8);

    var res_w: c_int = 0;
    var res_h: c_int = 0;
    _ = sdl.SDL_GetRendererOutputSize(zigsdl.getRenderer(), &res_w, &res_h);

    // draw a background
    draw_module.filled_rectangle(0, 0, res_w, height_pixels, 0);
    draw_module.filled_rectangle(0, height_pixels, res_w, 1, 1);

    var y_pos: i32 = @intCast(i32, console_num_to_show * 8);
    var count: u32 = 0;

    var start_index: usize = 0;
    if(log_history_list.items.len > console_num_to_show)
        start_index = log_history_list.items.len - console_num_to_show;

    text_module.drawText("> ", 0, y_pos, 1);
    y_pos -= 8;

    for(start_index .. log_history_list.items.len) |idx| {
        const line = log_history_list.items[log_history_list.items.len - 1 - idx];
        text_module.drawText(line, 0, y_pos, 1);
        y_pos -= 8;
        count += 1;

        if(count >= console_num_to_show)
            break;
    }
}

pub fn setConsoleVisible(is_visible: bool) void {
    console_visible = is_visible;
}

pub fn handleConsoleInput(char: u8) void {
    cmd_stream.print("{c}", char);
}
