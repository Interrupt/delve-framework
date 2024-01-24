// top level imports

pub const app = @import("app.zig");
pub const colors = @import("colors.zig");
pub const debug = @import("debug.zig");
pub const images = @import("images.zig");
pub const math = @import("math.zig");
pub const modules = @import("modules.zig");

// platform level imports

pub const graphics = @import("platform/graphics.zig");
pub const input = @import("platform/input.zig");
pub const audio = @import("platform/audio.zig");
pub const platform_app = @import("platform/app.zig");

// scripting imports

pub const scripting_lua = @import("scripting/lua.zig");
pub const scripting_manager = @import("scripting/manager.zig");

// module imports

pub const module_fps_counter = @import("modules/fps_counter.zig");
pub const module_lua_simple = @import("modules/lua_simple.zig");

// graphics imports

pub const graphics_batcher = @import("graphics/batcher.zig");
pub const graphics_camera = @import("graphics/camera.zig");
pub const graphics_mesh = @import("graphics/mesh.zig");

// scripting api imports

pub const api_assets = @import("api/assets.zig");
pub const api_display = @import("api/display.zig");
pub const api_draw = @import("api/draw.zig");
pub const api_graphics = @import("api/graphics.zig");
pub const api_keyboard = @import("api/keyboard.zig");
pub const api_mouse = @import("api/mouse.zig");
pub const api_text = @import("api/text.zig");

// builtin shaders

pub const shader_default_shader = @import("graphics/shaders/default.glsl.zig");
pub const shader_default_emissive = @import("graphics/shaders/emissive.glsl.zig");
