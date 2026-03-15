const colors = @import("../../../colors.zig");
const debug = @import("../../../debug.zig");
const graphics = @import("../../graphics.zig");
const images = @import("../../../images.zig");

pub fn init() !void {
    debug.log("Sokol null graphics backend starting", .{});
}

pub fn startFrame() void {}

pub fn endFrame() void {}

pub fn deinit() void {}

pub fn setClearColor(color: colors.Color) void {
    _ = color;
}

pub fn beginPass(render_pass: graphics.RenderPass, clear_color: ?colors.Color) void {
    _ = render_pass;
    _ = clear_color;
}

pub fn endPass() void {}

/// Sets the debug text drawing color
pub fn setDebugTextColor(color: colors.Color) void {
    _ = color;
}

/// Draws debug text on the screen
pub fn drawDebugText(x: f32, y: f32, str: [:0]const u8) void {
    _ = x;
    _ = y;
    _ = str;
}

/// Draws a single debug text character
pub fn drawDebugTextChar(x: f32, y: f32, char: u8) void {
    _ = x;
    _ = y;
    _ = char;
}

/// Sets the scaling used when drawing debug text
pub fn setDebugTextScale(scale: f32) void {
    _ = scale;
}

/// Returns the current text scale for debug text
pub fn getDebugTextScale() f32 {
    return 1.0;
}

pub const BindingsImpl = struct {};

pub var default_shader_impl: ShaderImpl = .{};

pub const ShaderImpl = struct {
    pub fn initDefault(cfg: graphics.ShaderConfig) !graphics.Shader {
        return .{
            .handle = 0,
            .cfg = cfg,
            .vertex_attributes = cfg.vertex_attributes,
            .shader_program_def = cfg.shader_program_def,
            .impl = &default_shader_impl,
        };
    }

    pub fn destroy(self: *graphics.Shader) void {
        _ = self;
    }

    /// Creates a shader from a shader built in as a zig file
    pub fn initFromBuiltin(cfg: graphics.ShaderConfig, comptime builtin: anytype) !graphics.Shader {
        _ = builtin;
        return .{
            .handle = 0,
            .cfg = cfg,
            .vertex_attributes = cfg.vertex_attributes,
            .shader_program_def = cfg.shader_program_def,
            .impl = &default_shader_impl,
        };
    }

    pub fn makeNewInstance(cfg: graphics.ShaderConfig, shader: graphics.Shader) !graphics.Shader {
        _ = cfg;
        return shader;
    }
};

pub const TextureImpl = struct {
    pub fn init(image: images.Image) TextureImpl {
        _ = image;
        return .{};
    }

    pub fn initFromBytes(width: u32, height: u32, image_bytes: anytype) TextureImpl {
        _ = width;
        _ = height;
        _ = image_bytes;
        return .{};
    }
    pub fn initRenderTexture(width: u32, height: u32, is_depth: bool) TextureImpl {
        _ = width;
        _ = height;
        _ = is_depth;
        return .{};
    }
    pub fn destroy(self: *TextureImpl) void {
        _ = self;
    }
    pub fn makeImguiTexture(self: *const TextureImpl) u64 {
        _ = self;
        return 0;
    }
};

pub const MaterialImpl = struct {
    pub fn init(cfg: graphics.MaterialConfig) !MaterialImpl {
        _ = cfg;
        return .{};
    }

    pub fn makeImguiTexture(self: *const graphics.Material, texture_idx: usize, sampler_idx: usize) u64 {
        _ = self;
        _ = texture_idx;
        _ = sampler_idx;
        return 0;
    }
};
