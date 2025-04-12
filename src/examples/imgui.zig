const delve = @import("delve");
const app = delve.app;
const graphics = delve.platform.graphics;
const std = @import("std");

const imgui = delve.imgui;

const test_image_asset = @embedFile("static/test.png");
var test_texture: graphics.Texture = undefined;
var test_material: graphics.Material = undefined;

var imgui_texture_1: ?*anyopaque = undefined;
var imgui_texture_2: ?*anyopaque = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// This example shows how to use Dear Imgui!

const imgui_module = delve.modules.Module{
    .name = "imgui_example",
    .init_fn = on_init,
    .tick_fn = on_tick,
    .draw_fn = on_draw,
    .cleanup_fn = on_cleanup,
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

    try app.start(app.AppConfig{ .title = "Delve Framework - Imgui Example" });
}

pub fn registerModule() !void {
    try delve.modules.registerModule(imgui_module);
}

pub fn on_init() !void {
    delve.debug.log("Imgui Example Initializing.", .{});

    // load an image
    var test_image = try delve.images.loadBytes(test_image_asset);
    defer test_image.deinit();

    // make a texture from it
    test_texture = graphics.Texture.init(test_image);

    // make an imgui texture for it
    imgui_texture_1 = test_texture.makeImguiTexture();

    // make a material to use a different sampler mode
    test_material = try delve.platform.graphics.Material.init(.{
        .shader = delve.platform.graphics.getDefaultShader(),
        .texture_0 = test_texture,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // and make an imgui texture out of our material
    imgui_texture_2 = test_material.makeImguiTexture();
}

fn on_cleanup() !void {
    delve.debug.log("Imgui example cleaning up", .{});
    test_texture.destroy();
    test_material.deinit();
}

pub fn on_tick(delta: f32) void {
    _ = delta;

    if (delve.platform.input.isKeyJustPressed(.ESCAPE)) {
        delve.platform.app.exit();
    }

    delve.platform.app.startImguiFrame();

    imgui.igSetNextWindowPos(.{ .x = 40, .y = 60 }, imgui.ImGuiCond_Once, .{ .x = 0, .y = 0 });
    imgui.igSetNextWindowSize(.{ .x = 400, .y = 300 }, imgui.ImGuiCond_Once);

    // start a window
    _ = imgui.igBegin("Hello Dear ImGui!", 0, imgui.ImGuiWindowFlags_None);

    _ = imgui.igColorEdit3("Background", &bg_color[0], imgui.ImGuiColorEditFlags_None);

    _ = imgui.igSpacing();

    _ = imgui.igImage(
        imgui_texture_1,
        .{ .x = 80, .y = 80 }, // size
        .{ .x = 0, .y = 0 }, // u
        .{ .x = 1.0, .y = 1.0 }, // v
        .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // tint color
        .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // border color
    );

    _ = imgui.igSpacing();

    _ = imgui.igImage(
        imgui_texture_2,
        .{ .x = 140, .y = 140 }, // size
        .{ .x = 0, .y = 0 }, // u
        .{ .x = 1.0, .y = 1.0 }, // v
        .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // tint color
        .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // border color
    );

    // end the window
    imgui.igEnd();

    delve.platform.graphics.setClearColor(delve.colors.Color.fromArray(bg_color));
}

pub fn on_draw() void {
    delve.platform.app.renderImgui();
}
