const std = @import("std");
const lua = @import("scripting/lua.zig");
const colors = @import("colors.zig");
const gfx = @import("platform/graphics.zig");
const text_module = @import("api/text.zig");
const draw_module = @import("api/draw.zig");

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

var last_text_height: i32 = 0;

// Other systems could init the debug system before the app does
var needs_init: bool = true;
var needs_deinit: bool = false;

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
    if(!needs_init)
        return;
    needs_init = false;
    needs_deinit = true;

    log_history_list = LogList.init(allocator);
    cmd_history_list = LogList.init(allocator);
    pending_cmd = char_array.init(allocator);
}

pub fn deinit() void {
    if(!needs_deinit)
        return;
    needs_deinit = false;
    needs_init = true;

    log_history_list.deinit();
    cmd_history_list.deinit();
    pending_cmd.deinit();
    _ = gpa.deinit();
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    if(needs_init)
        init();

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

pub fn drawConsole(draw_bg: bool) void {
    if (!console_visible)
        return;

    // Reset text drawing scale
    gfx.setDebugTextScale(1, 1);

    // Push text away from the top and left sides
    const padding = 2;

    const white_pal_idx = 7;
    const height_pixels: i32 = @intCast(((console_num_to_show + 1) * 9) + padding);
    last_text_height = height_pixels;

    var res_w: i32 = gfx.getDisplayWidth();
    var res_h: i32 = gfx.getDisplayHeight();
    _ = res_h;

    if(draw_bg) {
        drawConsoleBackground();
    }

    var y_draw_pos: i32 = (height_pixels - 8) - padding;

    // Draw the pending command text
    text_module.draw("> ", padding, y_draw_pos, white_pal_idx);
    var pending_cmd_idx: i32 = 0;
    for (pending_cmd.items) |char| {
        pending_cmd_idx += 1;
        text_module.drawGlyph(char, padding + pending_cmd_idx * 8, y_draw_pos, white_pal_idx);
    }

    // Draw the indicator
    pending_cmd_idx += 1;
    text_module.drawGlyph(221, padding + pending_cmd_idx * 8, y_draw_pos, white_pal_idx);

    // add some extra padding between the pending text and the history
    y_draw_pos -= 1;

    var cur = log_history_list.last();
    while (cur) |node| : (cur = node.prev) {
        // Stop drawing if off the screen!
        if (y_draw_pos <= 0)
            break;

        const line = node.data;
        const text_height = text_module.getTextHeight(line, res_w);
        text_module.draw_wrapped(line, padding, y_draw_pos - text_height, res_w, white_pal_idx);
        y_draw_pos -= text_height + 1;
    }
}

pub fn drawConsoleBackground() void {
    if (!console_visible)
        return;

    const height_pixels = last_text_height;
    const draw_height: f32 = @floatFromInt(height_pixels * 2);

    var res_w: f32 = @floatFromInt(gfx.getDisplayWidth());

    // draw a solid background
    gfx.drawDebugRectangle(gfx.tex_white, 0.0, 0.0, res_w, draw_height, colors.black);

    // and a bottom line
    gfx.drawDebugRectangle(gfx.tex_white, 0.0, draw_height, res_w, 2.0, colors.grey);
}

pub fn setConsoleVisible(is_visible: bool) void {
    if (console_visible == is_visible)
        return;

    console_visible = is_visible;
}

pub fn isConsoleVisible() bool {
    return console_visible;
}

pub fn handleKeyboardTextInput(char: u8) void {
    // Handle some special cases first
    if(char == 127) {
        handleKeyboardBackspace();
        return;
    } else if(char == 13) {
        runPendingCommand();
        return;
    }

    pending_cmd.append(char) catch {};
}

pub fn handleKeyDown(keycode: i32) void {
    if(keycode == 264) { // DOWN
        scrollCommandFromHistory(1);
    } else if(keycode == 265) { // UP
        scrollCommandFromHistory(-1);
    }
}

pub fn handleKeyboardBackspace() void {
    const len = pending_cmd.items.len;
    if(len == 0)
        return;

    _ = pending_cmd.orderedRemove(len - 1);
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

pub fn showErrorScreen(error_header: [:0]const u8) void {
    // Simple lua function to make the draw function draw an error screen
    const error_screen_lua =
        \\ _draw = function()
        \\ require('draw').clear(1)
        \\ require('text').draw("{s}", 32, 32, 0)
        \\ require('text').draw_wrapped([[{s}]], 32, 32+16, 800, 0)
        \\ end
        \\
        \\ _update = function() end
    ;

    // Assume that the last log line is what exploded!
    const log_history = getLogHistory();
    var error_desc: [:0]const u8 = undefined;
    if (log_history.last()) |last_log| {
        error_desc = last_log.data;
    } else {
        error_desc = "Something bad happened!";
    }

    // Only use until the first newline
    var error_desc_splits = std.mem.split(u8, error_desc, "\n");
    var first_split = error_desc_splits.first();

    const written = std.fmt.allocPrintZ(allocator, error_screen_lua, .{ error_header, first_split }) catch {
        std.debug.print("Error allocating to show error screen?\n", .{});
        return;
    };
    defer allocator.free(written);

    // run the new lua statement
    std.debug.print("Showing error screen: {s}\n", .{error_header});
    lua.runLine(written) catch {
        std.debug.print("Error running lua to show error screen?\n", .{});
    };
}
