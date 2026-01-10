const delve = @import("delve");
const app = delve.app;
const std = @import("std");

const imgui = delve.imgui;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// This example shows how to enable copy-paste in imgui!

const clipboard_size = 200; // Deliberately set low, to demonstrate clipping
const buffer_size = 1000;

const imgui_module = delve.modules.Module{
    .name = "clipboard_example",
    .init_fn = on_init,
    .tick_fn = on_tick,
    .draw_fn = on_draw,
};

var bg_color: [4]f32 = [4]f32{ 0.25, 0.85, 0.55, 1.0 };

pub fn main() !void {
    // Pick the allocator to use depending on platform
    const builtin = @import("builtin");
    if (builtin.os.tag == .wasi or builtin.os.tag == .emscripten) {
        // Web builds hack: use the C allocator to avoid OOM errors
        // See https://github.com/ziglang/zig/issues/19072
        try delve.init(std.heap.c_allocator);
    } else {
        // Using the default allocator will let us detect memory leaks
        try delve.init(delve.mem.createDefaultAllocator());
    }

    try registerModule();

    try app.start(app.AppConfig{
        .title = "Delve Framework - Clipboard Example",
        .enable_clipboard = true,
        .clipboard_size = clipboard_size,
    });
}

pub fn registerModule() !void {
    try delve.modules.registerModule(imgui_module);
}

var buffer: [buffer_size:0]u8 = [_:0]u8{0} ** buffer_size;

pub fn on_init() !void {
    delve.debug.log("Imgui Example Initializing.", .{});

    for (lorem_ipsum, 0..) |c, i| {
        buffer[i] = c;
        buffer[i+1] = 0;
    }
}


pub fn on_tick(delta: f32) void {
    _ = delta;

    if (delve.platform.input.isKeyJustPressed(.ESCAPE)) {
        delve.platform.app.exit();
    }

    delve.platform.app.startImguiFrame();

    // Window 1: Text box that we can edit/highlight/copy/paste in

    imgui.igSetNextWindowPos(.{ .x = 40, .y = 60 }, imgui.ImGuiCond_Once);
    imgui.igSetNextWindowSize(.{ .x = 400, .y = 300 }, imgui.ImGuiCond_Once);
    _ = imgui.igBegin("Hello Clipboard!", 0, imgui.ImGuiWindowFlags_None);
    {
        imgui.igText("Max clipboard size: %d", delve.platform.app.getClipboardSize().?);
        imgui.igSeparator();
        imgui.igTextUnformatted("Text box - supports copy/paste");
        
        imgui.igPushItemWidth(imgui.igGetWindowWidth() - 28.0); // Fill the window
        _ = imgui.igInputTextMultilineEx("##ti", &buffer, buffer.len + 1, .{}, imgui.ImGuiInputTextFlags_WordWrap, null, null);
        imgui.igPopItemWidth();

        imgui.igText("%d / %d", std.mem.sliceTo(&buffer, 0).len, buffer.len);

        if (imgui.igButton("Save to clipboard")) {
            imgui.igSetClipboardText(&buffer);
        }
    }
    imgui.igEnd();

    // Window 2: shows the current contents of the clipboard buffer

    var clipboard = imgui.igGetClipboardText(); // This function can return null
    if (clipboard == null) clipboard = "";

    const clipboard_len = std.mem.sliceTo(clipboard, 0).len;

    var buf1: [100]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buf1, "Clipboard - {} bytes", .{clipboard_len}) catch unreachable;

    imgui.igSetNextWindowPos(.{ .x = 500, .y = 20 }, imgui.ImGuiCond_Once);
    imgui.igSetNextWindowSize(.{ .x = 400, .y = 500 }, imgui.ImGuiCond_Once);
    _ = imgui.igBegin(text, 0, imgui.ImGuiWindowFlags_HorizontalScrollbar);
    {
        imgui.igSeparator();
        imgui.igTextUnformatted(clipboard);
    }
    imgui.igEnd();

    delve.platform.graphics.setClearColor(delve.colors.Color.fromArray(bg_color));
}

pub fn on_draw() void {
    delve.platform.app.renderImgui();
}

const lorem_ipsum =
\\Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum commodo 
\\dapibus tortor, et maximus nulla feugiat ut. Vivamus et velit ac libero 
\\iaculis euismod.
\\
\\Text that is larger than the clipboard buffer will be truncated!

;
