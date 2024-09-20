const std = @import("std");
const colors = @import("colors.zig");
const gfx = @import("platform/graphics.zig");
const mem = @import("mem.zig");
const papp = @import("platform/app.zig");
const text_module = @import("api/text.zig");
const draw_module = @import("api/draw.zig");

pub const ConsoleCommandFunc = union(enum) {
    fn_float: *const fn (f32) void,
    fn_int: *const fn (i32) void,
    fn_bool: *const fn (bool) void,
    fn_string: *const fn ([]const u8) void,
    fn_string_z: *const fn ([:0]const u8) void,
    fn_void: *const fn () void,
};

pub const ConsoleCommand = struct {
    command: []const u8,
    help: []const u8,
    func: ConsoleCommandFunc,
};

pub const ConsoleVariableType = union(enum) {
    addr_float: *f32,
    addr_int: *i32,
    addr_bool: *bool,
};

pub const ConsoleVariable = struct {
    variable: []const u8,
    help: []const u8,
    address: ConsoleVariableType,
};

pub var use_scripting_integration: bool = false;

const console_num_to_show: u32 = 8;
var console_visible = false;

/// The global log level. Increase to view more logs, decrease to view less.
pub var log_level = LogLevel.STANDARD;

var stack_fallback_allocator: std.heap.StackFallbackAllocator(256) = undefined;
var allocator: std.mem.Allocator = undefined;

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

// Keep track of any registered console commands and variables
var console_commands: std.StringHashMap(ConsoleCommand) = undefined;
var console_variables: std.StringHashMap(ConsoleVariable) = undefined;

// Other systems could init the debug system before the app does
var needs_init: bool = true;
var needs_deinit: bool = false;

const LogLevel = enum(u32) {
    FATAL,
    ERROR,
    WARNING,
    STANDARD,
    INFO,
    VERBOSE,
};

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

        std.mem.copyForwards(u8, log_mem, log_string);
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
        const node = self.items.popFirst();
        self.log_allocator.free(node.?.data);
        self.log_allocator.destroy(node.?);
    }

    /// Free all memory
    pub fn deinit(self: *LogList) void {
        var cur = self.items.first;
        while (cur) |node| {
            // First, free the node's data
            self.log_allocator.free(node.data);
            const to_delete = node;
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
    if (!needs_init)
        return;

    std.debug.print("Debug system initializing\n", .{});

    stack_fallback_allocator = std.heap.stackFallback(256, mem.getAllocator());
    allocator = stack_fallback_allocator.get();

    needs_init = false;
    needs_deinit = true;

    log_history_list = LogList.init(allocator);
    cmd_history_list = LogList.init(allocator);
    pending_cmd = char_array.init(allocator);

    console_commands = std.StringHashMap(ConsoleCommand).init(allocator);
    console_variables = std.StringHashMap(ConsoleVariable).init(allocator);

    registerConsoleCommand("help", doHelpCommand, "Lists all commands") catch {};
    registerConsoleCommand("exit", doExitCommand, "Quits app") catch {};
    registerConsoleCommand("echo", doEchoCommand, "Echoes input") catch {};
}

pub fn deinit() void {
    std.debug.print("Debug system deinitializing\n", .{});

    if (!needs_deinit)
        return;

    needs_deinit = false;
    needs_init = true;

    log_history_list.deinit();
    cmd_history_list.deinit();
    pending_cmd.deinit();

    console_commands.deinit();
    console_variables.deinit();

    // arena_allocator.deinit();
    // _ = gpa.deinit();
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    addLogEntry(fmt, args, .STANDARD);
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    addLogEntry(fmt, args, .INFO);
}

pub fn warning(comptime fmt: []const u8, args: anytype) void {
    addLogEntry("WARNING: " ++ fmt, args, .WARNING);
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    addLogEntry("ERROR: " ++ fmt, args, .ERROR);
}

pub fn fatal(comptime fmt: []const u8, args: anytype) void {
    addLogEntry("FATAL: " ++ fmt, args, .FATAL);
    papp.exitWithError();
}

fn addLogEntry(comptime fmt: []const u8, args: anytype, level: LogLevel) void {
    if (needs_init)
        init();

    // Only log if our log level is high enough
    if (@intFromEnum(log_level) < @intFromEnum(level)) {
        return;
    }

    // Use an array list to write our string
    var string_writer = std.ArrayList(u8).init(allocator);
    defer string_writer.deinit();

    string_writer.writer().print(fmt, args) catch {
        std.debug.print("Could not write to debug log! - Out of memory?\n", .{});
        return;
    };
    string_writer.append(0) catch {
        std.debug.print("Could not write to debug log! - Out of memory?\n", .{});
        return;
    };

    // Log to std out
    const written = string_writer.items;
    std.debug.print("{s}\n", .{written});

    // Keep the line in the console log
    log_history_list.push(written[0 .. written.len - 1 :0]);
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
    const text_scale: i32 = 2;
    const glyph_size: i32 = 8 * text_scale;
    gfx.setDebugTextScale(text_scale / 2);

    // Push text away from the top and left sides
    const padding = 2;

    const white_pal_idx = 7;
    const height_pixels: i32 = @intCast(((console_num_to_show + 1) * 9) + padding + 4);
    last_text_height = height_pixels;

    const res_w: i32 = gfx.getDisplayWidth();
    const res_h: i32 = gfx.getDisplayHeight();
    _ = res_h;

    if (draw_bg) {
        drawConsoleBackground();
    }

    var y_draw_pos: i32 = (height_pixels - 8) - padding;
    y_draw_pos *= text_scale;

    // Draw the pending command text
    text_module.draw("> ", padding, y_draw_pos, white_pal_idx);
    var pending_cmd_idx: i32 = 0;
    for (pending_cmd.items) |char| {
        pending_cmd_idx += 1;
        text_module.drawGlyph(char, padding + pending_cmd_idx * glyph_size, y_draw_pos, white_pal_idx);
    }

    // Draw the indicator
    pending_cmd_idx += 1;
    text_module.drawGlyph(221, padding + pending_cmd_idx * glyph_size, y_draw_pos, white_pal_idx);

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

    const res_w: f32 = @floatFromInt(gfx.getDisplayWidth());

    // draw a solid background
    gfx.drawDebugRectangle(gfx.tex_white, 0.0, 0.0, res_w, draw_height, colors.black);

    // and a bottom line
    gfx.drawDebugRectangle(gfx.tex_white, 0.0, draw_height, res_w, 2.0, colors.grey);
}

var mouse_was_captured: bool = false;
pub fn setConsoleVisible(is_visible: bool) void {
    if (console_visible == is_visible)
        return;

    console_visible = is_visible;

    if (console_visible) {
        mouse_was_captured = papp.isMouseCaptured();
        papp.captureMouse(false);
    } else {
        papp.captureMouse(mouse_was_captured);
    }
}

pub fn isConsoleVisible() bool {
    return console_visible;
}

pub fn handleKeyboardTextInput(char: u8) void {
    // Handle some special cases first
    if (char == 127) {
        handleKeyboardBackspace();
        return;
    } else if (char == 13) {
        // ignore enter, seems to hit both this and handleKeyDown
        return;
    }

    pending_cmd.append(char) catch {};
}

pub fn handleKeyDown(keycode: i32) void {
    switch (keycode) {
        264 => { // DOWN
            scrollCommandFromHistory(1);
        },
        265 => { // UP
            scrollCommandFromHistory(-1);
        },
        257 => { // ENTER
            runPendingCommand();
        },
        259 => { // BACKSPACE
            handleKeyboardBackspace();
        },
        else => {},
    }
}

pub fn handleKeyboardBackspace() void {
    const len = pending_cmd.items.len;
    if (len == 0)
        return;

    _ = pending_cmd.orderedRemove(len - 1);
}

pub fn runPendingCommand() void {
    // Run the entered command!
    log(">{s}", .{pending_cmd.items});
    defer pending_cmd.clearAndFree();

    // Ensure there is a sentinel at the end
    pending_cmd.append(0x00) catch {};

    const final_command = pending_cmd.items[0 .. pending_cmd.items.len - 1 :0];
    defer trackCommand(final_command);

    // Try to run commands
    const result = tryRegisteredCommands(final_command);
    switch (result) {
        .not_found => {
            log("Unknown command: \'{s}\'", .{final_command});
            log("Use \'help\' to see a list of commands", .{});
        },
        .invalid_args => {
            log("Invalid args: {s}", .{final_command});
        },
        .err => {
            log("Error during command: \'{s}\'", .{final_command});
        },
        .ok => {},
    }
}

pub const CommandResult = enum {
    ok,
    not_found,
    invalid_args,
    err,
};

pub fn tryRegisteredCommands(command_with_args: [:0]u8) CommandResult {
    var it = std.mem.splitAny(u8, command_with_args, " ");

    var command: []const u8 = undefined;
    if (it.next()) |cmd| {
        command = cmd;
    } else {
        // ignore empty commands
        return .not_found;
    }

    // collect all of the arguments into a list of arguments for commands to use
    var arg_list = std.ArrayList([]const u8).init(allocator);
    defer arg_list.clearAndFree();

    while (it.next()) |arg| {
        arg_list.append(arg) catch {
            return .err;
        };
    }

    // check if we have any registered console commands
    if (console_commands.getPtr(command)) |c| {
        if (command_with_args.len > command.len + 1) {
            const args = command_with_args[command.len + 1 .. command_with_args.len :0];
            switch (c.func) {
                .fn_float => {
                    const val: f32 = std.fmt.parseFloat(f32, args) catch {
                        return .invalid_args;
                    };
                    c.func.fn_float(val);
                },
                .fn_int => {
                    const val: i32 = std.fmt.parseInt(i32, args, 10) catch {
                        return .invalid_args;
                    };
                    c.func.fn_int(val);
                },
                .fn_bool => {
                    if (std.mem.eql(u8, "true", args)) {
                        c.func.fn_bool(true);
                    } else if (std.mem.eql(u8, "false", args)) {
                        c.func.fn_bool(false);
                    } else if (std.mem.eql(u8, "1", args)) {
                        c.func.fn_bool(true);
                    } else if (std.mem.eql(u8, "0", args)) {
                        c.func.fn_bool(false);
                    } else {
                        return .invalid_args;
                    }
                },
                .fn_string => {
                    c.func.fn_string(args);
                },
                .fn_string_z => {
                    c.func.fn_string_z(args);
                },
                .fn_void => {
                    c.func.fn_void();
                },
            }
        } else {
            switch (c.func) {
                .fn_void => {
                    c.func.fn_void();
                },
                else => {
                    return .invalid_args;
                },
            }
        }

        return .ok;
    }

    // check if we have any registered console variables
    if (console_variables.getPtr(command)) |c| {
        if (command_with_args.len > command.len + 1) {
            const args = command_with_args[command.len + 1 .. command_with_args.len :0];
            switch (c.address) {
                .addr_float => {
                    const val: f32 = std.fmt.parseFloat(f32, args) catch {
                        return .invalid_args;
                    };
                    c.address.addr_float.* = val;
                },
                .addr_int => {
                    const val: i32 = std.fmt.parseInt(i32, args, 10) catch {
                        return .invalid_args;
                    };
                    c.address.addr_int.* = val;
                },
                .addr_bool => {
                    if (std.mem.eql(u8, "true", args)) {
                        c.address.addr_bool.* = true;
                    } else if (std.mem.eql(u8, "false", args)) {
                        c.address.addr_bool.* = false;
                    } else if (std.mem.eql(u8, "1", args)) {
                        c.address.addr_bool.* = true;
                    } else if (std.mem.eql(u8, "0", args)) {
                        c.address.addr_bool.* = false;
                    } else {
                        return .invalid_args;
                    }
                },
            }
        } else {
            log("{s}: {d:3}", .{ command, c.address.addr_float.* });
        }

        return .ok;
    }

    return .not_found;
}

pub fn registerConsoleCommand(command: []const u8, comptime func: anytype, help: []const u8) !void {
    if (needs_init)
        init();

    switch (@TypeOf(func)) {
        fn ([]const u8) void => {
            try console_commands.put(command, .{ .command = command, .help = help, .func = .{ .fn_string = func } });
        },
        fn ([:0]const u8) void => {
            try console_commands.put(command, .{ .command = command, .help = help, .func = .{ .fn_string_z = func } });
        },
        fn (i32) void => {
            try console_commands.put(command, .{ .command = command, .help = help, .func = .{ .fn_int = func } });
        },
        fn (f32) void => {
            try console_commands.put(command, .{ .command = command, .help = help, .func = .{ .fn_float = func } });
        },
        fn (bool) void => {
            try console_commands.put(command, .{ .command = command, .help = help, .func = .{ .fn_bool = func } });
        },
        fn () void => {
            try console_commands.put(command, .{ .command = command, .help = help, .func = .{ .fn_void = func } });
        },
        else => {
            @compileError("Unknown console command type!");
        },
    }
}

pub fn registerConsoleVariable(variable: []const u8, comptime address: anytype, help: []const u8) !void {
    if (needs_init)
        init();

    switch (@TypeOf(address)) {
        *f32 => {
            try console_variables.put(variable, .{ .variable = variable, .help = help, .address = .{ .addr_float = address } });
        },
        *i32 => {
            try console_variables.put(variable, .{ .variable = variable, .help = help, .address = .{ .addr_int = address } });
        },
        *bool => {
            try console_variables.put(variable, .{ .variable = variable, .help = help, .address = .{ .addr_bool = address } });
        },
        else => {
            @compileError("Unknown console variable type!");
        },
    }
}

// Shows an error screen
pub fn showErrorScreen(error_header: [:0]const u8) void {
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
    const first_split = error_desc_splits.first();

    // todo: show an error screen! until then, just print the error and exit
    std.debug.print("--- Fatal Error: {s}\n{s}\n", .{ error_header, first_split });

    const app = @import("platform/app.zig");
    app.exit();
}

// Console command to print the list of all commands
pub fn doHelpCommand() void {
    // print any registered commands
    if (console_commands.count() > 0) {
        log("-- Console Commands --", .{});

        var cmd_it = console_commands.valueIterator();
        while (cmd_it.next()) |cmd| {
            log("{s}: {s}", .{ cmd.command, cmd.help });
        }
    }

    // print any registered variables
    if (console_variables.count() > 0) {
        log("-- Console Variables --", .{});

        var var_it = console_variables.valueIterator();
        while (var_it.next()) |variable| {
            log("{s}: {s}", .{ variable.variable, variable.help });
        }
    }
}

// console command to exit the app
pub fn doExitCommand() void {
    log("Shutting down.", .{});

    const app = @import("platform/app.zig");
    app.exit();
}

// console command to echo input
pub fn doEchoCommand(args: []const u8) void {
    log("{s}", .{args});
}
