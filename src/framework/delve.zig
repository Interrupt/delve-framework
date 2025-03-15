const std = @import("std");

// top level imports

pub const app = @import("app.zig");
pub const colors = @import("colors.zig");
pub const debug = @import("debug.zig");
pub const images = @import("images.zig");
pub const fonts = @import("fonts.zig");
pub const math = @import("math.zig");
pub const mem = @import("mem.zig");

// platform level imports

pub const platform = struct {
    pub const app = @import("platform/app.zig");
    pub const audio = @import("platform/audio.zig");
    pub const graphics = @import("platform/graphics.zig");
    pub const input = @import("platform/input.zig");
};

// scripting imports

pub const scripting = struct {
    pub const lua = @import("scripting/lua.zig");
    pub const manager = @import("scripting/manager.zig");
};

// module imports

pub const modules = @import("modules.zig");
pub const module = struct {
    pub const fps_counter = @import("modules/fps_counter.zig");
    pub const lua_simple = @import("modules/lua_simple.zig");
};

// graphics imports

pub const graphics = struct {
    pub const batcher = @import("graphics/batcher.zig");
    pub const camera = @import("graphics/camera.zig");
    pub const mesh = @import("graphics/mesh.zig");
    pub const shaders = @import("graphics/shaders.zig");
    pub const skinned_mesh = @import("graphics/skinned-mesh.zig");
    pub const sprites = @import("graphics/sprites.zig");
};

// scripting api imports

pub const api = struct {
    pub const assets = @import("api/assets.zig");
    pub const display = @import("api/display.zig");
    pub const draw = @import("api/draw.zig");
    pub const graphics = @import("api/graphics.zig");
    pub const keyboard = @import("api/keyboard.zig");
    pub const mouse = @import("api/mouse.zig");
    pub const text = @import("api/text.zig");
};

pub const spatial = struct {
    pub const BoundingBox = @import("spatial/boundingbox.zig").BoundingBox;
    pub const OrientedBoundingBox = @import("spatial/orientedboundingbox.zig").OrientedBoundingBox;
    pub const Frustum = @import("spatial/frustum.zig").Frustum;
    pub const Plane = @import("spatial/plane.zig").Plane;
    pub const Ray = @import("spatial/rays.zig").Ray;
    pub const Rect = @import("spatial/rect.zig").Rect;
};

pub const utils = struct {
    pub const interpolation = @import("utils/interpolation.zig");
    pub const quakemap = @import("utils/quakemap.zig");
    pub const quakemdl = @import("utils/quakemdl.zig");
};

// builtin shaders

pub const shaders = struct {
    pub const default = @import("graphics/shaders/default.glsl.zig");
    pub const default_mesh = @import("graphics/shaders/default-mesh.glsl.zig");
    pub const default_emissive = @import("graphics/shaders/emissive.glsl.zig");
    pub const default_skinned = @import("graphics/shaders/skinned.glsl.zig");
    pub const default_basic_lighting = @import("graphics/shaders/basic-lighting.glsl.zig");
    pub const default_skinned_basic_lighting = @import("graphics/shaders/skinned-basic-lighting.glsl.zig");
};

// dear imgui

pub const imgui = @import("cimgui");

// initial setup. Call before any other Delve Framework functions!
pub fn init(allocator: std.mem.Allocator) !void {
    mem.init(allocator);
    debug.log("Delve Framework Initialized", .{});
}

test {
    // can run these via 'zig test src/framework/delve.zig'
    @import("std").testing.refAllDecls(math);
    @import("std").testing.refAllDecls(spatial);
    @import("std").testing.refAllDecls(platform);
    @import("std").testing.refAllDecls(utils);
}
