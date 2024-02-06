// top level imports

pub const app = @import("app.zig");
pub const colors = @import("colors.zig");
pub const debug = @import("debug.zig");
pub const images = @import("images.zig");
pub const math = @import("math.zig");

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
    pub const Rect = @import("spatial/rect.zig").Rect;
};

// builtin shaders

pub const shaders = struct {
    pub const default = @import("graphics/shaders/default.glsl.zig");
    pub const default_emissive = @import("graphics/shaders/emissive.glsl.zig");
};
