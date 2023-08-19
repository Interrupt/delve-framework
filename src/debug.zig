const std = @import("std");
const zigsdl = @import("sdl.zig");
const lua = @import("lua.zig");
const text_module = @import("modules/text.zig");
const draw_module = @import("modules/draw.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const console_num_to_show: u32 = 8;
var console_visible = false;

// Manage our own memory!
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

// List types
const StringLinkedList = std.TailQueue([:0]const u8);
const char_array = std.ArrayList(u8);

// Lists for log history and command history
var log_history_list: LogList = undefined;
var cmd_history_list: LogList = undefined;

// Keep track of a specific command for scrolling through history
var cmd_history_item: ?*StringLinkedList.Node = undefined;
var cmd_history_last_direction: i32 = 0;

var pending_cmd: std.ArrayList(u8) = undefined;

/// A Linked List that can manage its own memory
const LogList = struct {
    items: StringLinkedList = StringLinkedList{},
    log_allocator: std.mem.Allocator = undefined,
    max_len: usize = 100,

    /// Creates a new LogList
    pub fn init(in_allocator: std.mem.Allocator) LogList {
        return LogList{
            .log_allocator = in_allocator,
        };
    }

    /// Add a log string to the end of the list
    pub fn push(self: *LogList, log_string: [:0]const u8) void {
        const log_mem = self.log_allocator.alloc(u8, log_string.len + 1) catch {
            return;
        };
        std.mem.copy(u8, log_mem, log_string);
        log_mem[log_mem.len - 1] = 0x00; // Ensure the sentinel

        var node: *StringLinkedList.Node = self.log_allocator.create(StringLinkedList.Node) catch {
            return;
        };

        node.data = log_mem[0 .. log_mem.len - 1 :0];
        self.items.append(node);

        // Never go over max!
        if (self.items.len > self.max_len) {
            self.removeFirst();
        }
    }

    /// Remove the first item from the list, cleaning up data
    pub fn removeFirst(self: *LogList) void {
        var node = self.items.popFirst();
        self.log_allocator.free(node.?.data);
        self.log_allocator.destroy(node.?);
    }

    /// Free all memory
    pub fn deinit(self: *LogList) void {
        var cur = self.items.first;
        while (cur) |node| {
            // First, free the node's data
            self.log_allocator.free(node.data);
            var to_delete = node;
            cur = node.next;

            // Finally, clean up the node itself
            self.log_allocator.destroy(to_delete);
        }
    }

    pub fn first(self: *LogList) ?*StringLinkedList.Node {
        return self.items.first;
    }

    pub fn last(self: *LogList) ?*StringLinkedList.Node {
        return self.items.last;
    }

    pub fn len(self: *LogList) usize {
        return self.items.len;
    }
};

pub fn init() void {
    log_history_list = LogList.init(allocator);
    cmd_history_list = LogList.init(allocator);
    pending_cmd = char_array.init(allocator);
}

pub fn deinit() void {
    log_history_list.deinit();
    cmd_history_list.deinit();
    pending_cmd.deinit();
    _ = gpa.deinit();
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    const written = std.fmt.allocPrintZ(allocator, fmt, args) catch {
        std.debug.print(fmt ++ "\n", args);
        std.debug.print("Error logging to console. Out of memory?\n", .{});
        return;
    };
    defer allocator.free(written);

    // Log to std out
    std.debug.print("{s}\n", .{written});

    // Keep the line in the console log
    log_history_list.push(written[0..written.len :0]);
}

pub fn getLogHistory() *LogList {
    return &log_history_list;
}

pub fn trackCommand(command: [:0]const u8) void {
    // Append the command to the history
    cmd_history_list.push(command);

    // Reset the history picked item
    cmd_history_item = null;
    cmd_history_last_direction = 0;
}

pub fn scrollCommandFromHistory(direction: i32) void {
    if (cmd_history_list.len() == 0)
        return;

    // Keep track of this direction for the next scroll
    defer cmd_history_last_direction = direction;

    // Reset the pending command
    pending_cmd.clearAndFree();

    if (cmd_history_item == null) {
        // If off the list, pick the start or end
        if (direction < 0 and cmd_history_last_direction >= 0)
            cmd_history_item = cmd_history_list.last();
        if (direction > 0 and cmd_history_last_direction <= 0)
            cmd_history_item = cmd_history_list.first();
    } else {
        // In the list, scroll up and down
        if (direction < 0)
            cmd_history_item = cmd_history_item.?.prev;
        if (direction > 0)
            cmd_history_item = cmd_history_item.?.next;
    }

    // If there is no history item, show nothing!
    if (cmd_history_item == null)
        return;

    // Within bounds, use the old command
    pending_cmd.appendSlice(cmd_history_item.?.data) catch {};
}

pub fn drawConsole() void {
    if (!console_visible)
        return;

    // Push text away from the top and left sides
    const padding = 2;

    const white_pal_idx = 7;
    const height_pixels = @as(i32, @intCast(((console_num_to_show + 1) * 8) + padding));

    var res_w: c_int = 0;
    var res_h: c_int = 0;
    _ = sdl.SDL_GetRendererOutputSize(zigsdl.getRenderer(), &res_w, &res_h);

    // draw a background
    draw_module.filled_rectangle(0, 0, res_w, height_pixels, 0);
    draw_module.filled_rectangle(0, height_pixels, res_w, 1, 1);

    var y_draw_pos: i32 = (height_pixels - 8) - padding;

    // Draw the pending command text
    text_module.drawText("> ", padding, y_draw_pos, white_pal_idx);
    var pending_cmd_idx: i32 = 0;
    for (pending_cmd.items) |char| {
        pending_cmd_idx += 1;
        text_module.drawGlyph(char, padding + pending_cmd_idx * 8, y_draw_pos, white_pal_idx);
    }

    // Draw the indicator
    pending_cmd_idx += 1;
    text_module.drawGlyph(221, padding + pending_cmd_idx * 8, y_draw_pos, white_pal_idx);

    var cur = log_history_list.last();
    while (cur) |node| : (cur = node.prev) {
        // Stop drawing if off the screen!
        if (y_draw_pos <= 0)
            break;

        const line = node.data;
        const text_height = text_module.getTextHeight(line, 252);
        text_module.drawTextWrapped(line, padding, y_draw_pos - text_height, 252, white_pal_idx);
        y_draw_pos -= text_height;
    }
}

pub fn setConsoleVisible(is_visible: bool) void {
    if (console_visible == is_visible)
        return;

    console_visible = is_visible;

    if (is_visible) {
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

    const final_command = pending_cmd.items[0 .. pending_cmd.items.len - 1 :0];
    lua.runLine(final_command) catch {};
    trackCommand(final_command);
}

pub fn handleSDLInputEvent(sdl_event: sdl.SDL_Event) bool {
    switch (sdl_event.type) {
        sdl.SDL_KEYDOWN => {
            switch (sdl_event.key.keysym.sym) {
                sdl.SDLK_RETURN => {
                    runPendingCommand();
                    return true;
                },
                sdl.SDLK_BACKSPACE => {
                    if (pending_cmd.items.len > 0)
                        _ = pending_cmd.pop();
                    return true;
                },
                sdl.SDLK_BACKQUOTE => {
                    if (sdl.SDL_GetModState() & sdl.KMOD_SHIFT == 1) {
                        // Hide on tilde
                        setConsoleVisible(false);
                        return true;
                    }
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
            // Ignore tildes. Easiest way to handle toggle
            if (sdl_event.text.text[0] == '~')
                return false;

            handleKeyboardTextInput(sdl_event.text.text[0]);
            return true;
        },
        else => {},
    }

    return false;
}
