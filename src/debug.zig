const std = @import("std");
const zigsdl = @import("sdl.zig");
const lua = @import("lua.zig");
const text_module = @import("modules/text.zig");
const draw_module = @import("modules/draw.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const log_history_max_len = 100;
const cmd_history_max_len = 100;
const console_num_to_show: u32 = 8;

var console_visible = true;
var cmd_history_item: u32 = 0;

// Manage our own memory!
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

// Lists of log history and command history
const text_array = std.ArrayList([:0]const u8);
const char_array = std.ArrayList(u8);

var log_history_list: std.ArrayListAligned([:0]const u8, null) = undefined;
var cmd_history_list: std.ArrayListAligned([:0]const u8, null) = undefined;
var pending_cmd: std.ArrayListAligned(u8, null) = undefined;

pub fn init() void {
    log_history_list = text_array.init(allocator);
    cmd_history_list = text_array.init(allocator);
    pending_cmd = char_array.init(allocator);

    // Put a blank at the beginning of the history
    trackCommand("");
}

pub fn deinit() void {
    for(log_history_list.items) |line| { allocator.free(line); }
    log_history_list.deinit();

    for(cmd_history_list.items) |line| { allocator.free(line); }
    cmd_history_list.deinit();

    pending_cmd.deinit();
    _ = gpa.deinit();
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    // Make an output stream for the console log line formatting
    var buf: [256:0]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const stream = fbs.writer();

    stream.print(fmt, args) catch { return; };
    stream.print("\x00", .{}) catch { return; };

    // Log to std out
    const written = fbs.getWritten();
    std.debug.print("{s}", .{written});

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

pub fn trackCommand(command: [:0]const u8) void {
    // Alloc some memory to keep a copy of this command in the history
    const memory = allocator.alloc(u8, command.len + 1) catch { return; };
    std.mem.copy(u8, memory, command);

    // Add the sentinel back
    memory[command.len] = 0x00;


    // Now append the log line to the history
    cmd_history_list.append(memory[0..memory.len-1 :0]) catch |err| {
        std.debug.print("Console command history append error: {}\n", .{err});
    };


    // Update the command history picked item
    defer cmd_history_item = @intCast(u32, cmd_history_list.items.len);

    // Compact the history if growing out of bounds
    if(cmd_history_list.items.len <= cmd_history_max_len)
        return;

    const removed = cmd_history_list.orderedRemove(0);
    allocator.free(removed);
}

pub fn scrollCommandFromHistory(direction: i32) void {
    if(cmd_history_list.items.len == 0)
        return;

    // Reset the pending command
    pending_cmd.clearAndFree();

    // Use the blank command for out of the lower bounds
    if(direction < 0 and cmd_history_item == 0)
        return;

    // Scroll up and down
    if(direction < 0)
        cmd_history_item -= 1;
    if(direction > 0)
        cmd_history_item += 1;

    // Out of upper bounds?
    if(cmd_history_item > cmd_history_list.items.len - 1) {
        cmd_history_item = @intCast(u32, cmd_history_list.items.len);
        return;
    }

    // Within bounds, use the old command
    pending_cmd.appendSlice(cmd_history_list.items[cmd_history_item]) catch {};
}

pub fn drawConsole() void {
    if(!console_visible)
        return;

    // Push text away from the top and left sides
    const padding = 2;

    const white_pal_idx = 7;
    const height_pixels = @intCast(i32, (console_num_to_show + 1) * 8) + padding * 2;

    var res_w: c_int = 0;
    var res_h: c_int = 0;
    _ = sdl.SDL_GetRendererOutputSize(zigsdl.getRenderer(), &res_w, &res_h);

    // draw a background
    draw_module.filled_rectangle(0, 0, res_w, height_pixels, 0);
    draw_module.filled_rectangle(0, height_pixels, res_w, 1, 1);

    var y_draw_pos: i32 = @intCast(i32, console_num_to_show * 8) + padding;

    // How many lines should we draw?
    var start_index: usize = 0;
    if(log_history_list.items.len > console_num_to_show)
        start_index = log_history_list.items.len - console_num_to_show;

    const end_index = log_history_list.items.len;
    const line_count = end_index - start_index;

    // Draw the pending command text
    text_module.drawText("> ", padding, y_draw_pos, white_pal_idx);
    var pending_cmd_idx: i32 = 0;
    for(pending_cmd.items) |char| {
        pending_cmd_idx += 1;
        text_module.drawGlyph(char, padding + pending_cmd_idx * 8, y_draw_pos, white_pal_idx);
    }

    // Draw the indicator
    pending_cmd_idx += 1;
    text_module.drawGlyph(221, padding + pending_cmd_idx * 8, y_draw_pos, white_pal_idx);

    y_draw_pos -= 8;
    for(0 .. line_count) |idx| {
        const line = log_history_list.items[end_index - 1 - idx];
        text_module.drawText(line, padding, y_draw_pos, white_pal_idx);
        y_draw_pos -= 8;
    }
}

pub fn setConsoleVisible(is_visible: bool) void {
    if(console_visible == is_visible)
        return;

    console_visible = is_visible;

    if(is_visible) {
        sdl.SDL_StartTextInput();
        return;
    }

    sdl.SDL_StopTextInput();
}

pub fn isConsoleVisible() bool {
    return console_visible;
}

pub fn handleKeyboardTextInput(char: u8) void {
    pending_cmd.append(char) catch {};
}

pub fn handleKeyboardBackspace() void {
    pending_cmd.orderedRemove(0);
}

pub fn runPendingCommand() void {
    // Run the lua command!
    log("{s}", .{pending_cmd.items});
    defer pending_cmd.clearAndFree();

    // Ensure there is a sentinel at the end
    pending_cmd.append(0x00) catch {};

    const final_command = pending_cmd.items[0..pending_cmd.items.len-1 :0];
    lua.runLine(final_command) catch {};
    trackCommand(final_command);
}

pub fn handleSDLInputEvent(sdl_event: sdl.SDL_Event) bool {
    switch (sdl_event.type) {
        sdl.SDL_KEYDOWN => {
            switch(sdl_event.key.keysym.sym) {
                sdl.SDLK_RETURN => {
                    runPendingCommand();
                    return true;
                },
                sdl.SDLK_BACKSPACE => {
                    if(pending_cmd.items.len > 0)
                        _ = pending_cmd.pop();
                    return true;
                },
                sdl.SDLK_UP => {
                    scrollCommandFromHistory(-1);
                    return true;
                },
                sdl.SDLK_DOWN => {
                    scrollCommandFromHistory(1);
                    return true;
                },
                else => {},
            }
        },
        sdl.SDL_TEXTINPUT => {
            // Hide when tilde is pressed!
            if(sdl_event.text.text[0] == '~') {
                setConsoleVisible(!console_visible);
                return true;
            }

            handleKeyboardTextInput(sdl_event.text.text[0]);
            return true;
        },
        else => {},
    }

    return false;
}
