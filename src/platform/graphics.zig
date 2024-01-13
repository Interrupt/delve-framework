const std = @import("std");
const debug = @import("../debug.zig");
const images = @import("../images.zig");
const math = @import("../math.zig");
const papp = @import("app.zig");
const sokol_gfx_backend = @import("backends/sokol/graphics.zig");

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;
const debugtext = sokol.debugtext;


// compile built-in shaders via:
// ./sokol-shdc -i assets/shaders/default.glsl -o src/graphics/shaders/default.glsl.zig -l glsl300es:glsl330:wgsl:metal_macos:metal_ios:metal_sim:hlsl4 -f sokol_zig
pub const shader_default = @import("../graphics/shaders/default.glsl.zig");

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

pub var tex_white: Texture = undefined;
pub var tex_black: Texture = undefined;
pub var tex_grey: Texture = undefined;

// TODO: Where should the math library stuff live?
// Foster puts everything in places like /Spatial or /Graphics
// Look into using a third party math.zig instead of sokol's
// A vertex struct with position, color and uv-coords
// TODO: Stop using packed color and uvs!

pub const BlendMode = enum {
    NONE, // opaque!
    BLEND,
    ADD,
    MOD,
    MUL,
};

pub const CompareFunc = enum(i32) {
    DEFAULT,
    NEVER,
    LESS,
    EQUAL,
    LESS_EQUAL,
    GREATER,
    NOT_EQUAL,
    GREATER_EQUAL,
    ALWAYS,
    NUM,
};

pub const CullMode = enum(i32) {
    NONE,
    FRONT,
    BACK,
};

/// Default vertex shader uniform block layout
pub const VSDefaultUniforms = struct {
    projViewMatrix: math.Mat4 align(16),
    modelMatrix: math.Mat4,
    in_color: [4]f32 = .{1.0, 1.0, 1.0, 1.0},
};

/// Default fragment shader uniform block layout
pub const FSDefaultUniforms = struct {
    in_color_override: [4]f32 align(16) = .{0.0, 0.0, 0.0, 0.0},
    in_alpha_cutoff: f32 = 0.0,
};

// A struct that could contain anything
pub const Anything = struct {
    ptr: ?*const anyopaque = null,
    size: usize = 0,
};

pub const Vertex = struct {
    x: f32,
    y: f32,
    z: f32,
    color: u32 = 0xFFFFFFFF,
    u: f32 = 0,
    v: f32 = 0,

    pub fn mulMat4(left: Vertex, right: Mat4) Vertex {
        var ret = left;
        const vec = Vec3.new(left.x, left.y, left.z).mulMat4(right);
        ret.x = vec.x;
        ret.y = vec.y;
        ret.z = vec.z;
        return ret;
    }
};

// TODO: Move this to somewhere else. color.zig?
pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,

    pub fn new(r: f32, g: f32, b: f32, a: f32) Color {
       return Color{.r=r,.g=g,.b=b,.a=a};
    }

    pub fn fromArray(val: [4]f32) Color {
       return Color{.r=val[0],.g=val[1],.b=val[2],.a=val[3]};
    }

    pub fn white() Color {
       return Color{.r=1.0,.g=1.0,.b=1.0,.a=1.0};
    }

    pub fn black() Color {
       return Color{.r=0.0,.g=0.0,.b=0.0,.a=1.0};
    }

    pub fn transparent() Color {
       return Color{.r=0.0,.g=0.0,.b=0.0,.a=0.0};
    }

    pub fn grey() Color {
       return Color{.r=0.5,.g=0.5,.b=0.5,.a=1.0};
    }

    pub fn toInt(self: Color) u32 {
        var c: u32 = 0;
        c |= @intFromFloat(self.r * 0x000000FF);
        c |= @intFromFloat(self.g * 0x0000FF00);
        c |= @intFromFloat(self.b * 0x00FF0000);
        c |= @intFromFloat(self.a * 0xFF000000);
        return c;
    }

    pub fn toArray(self: Color) [4]f32 {
        return [_]f32 { self.r, self.g, self.b, self.a };
    }
};

pub const BindingConfig = struct {
    updatable: bool = false,
    vert_len: usize = 3200,
    index_len: usize = 3200,
};

pub const BindingsImpl = sokol_gfx_backend.BindingsImpl;

pub const Bindings = struct {
    length: usize,
    config: BindingConfig,
    impl: BindingsImpl,

    pub fn init(cfg: BindingConfig) Bindings {
        return BindingsImpl.init(cfg);
    }

    /// Creates new buffers to hold these vertices and indices
    pub fn set(self: *Bindings, vertices: anytype, indices: anytype, length: usize) void {
        BindingsImpl.set(self, vertices, indices, length);
    }

    /// Updates the existing buffers with new data
    pub fn update(self: *Bindings, vertices: anytype, indices: anytype, vert_len: usize, index_len: usize) void {
        BindingsImpl.update(self, vertices, indices, vert_len, index_len);
    }

    /// Sets the texture that will be used to draw this binding
    pub fn setTexture(self: *Bindings, texture: Texture) void {
        BindingsImpl.setTexture(self, texture);
    }

    /// Sets values from the material that will be used to draw this
    fn updateFromMaterial(self: *Bindings, material: *Material) void {
        BindingsImpl.updateFromMaterial(self, material);
    }

    /// Destroy our binding
    pub fn destroy(self: *Bindings) void {
        BindingsImpl.destroy(self);
    }

    /// Resize buffers used by our binding. Will destroy buffers and recreate them!
    pub fn resize(self: *Bindings, vertex_len: usize, index_len: usize) void {
        BindingsImpl.resize(self, vertex_len, index_len);
    }
};

pub const IndexSize = enum(i32) {
    UINT16,
    UINT32,
};

pub const FilterMode = enum(i32) {
    NEAREST,
    LINEAR,
};

pub const ShaderStage = enum(i32) {
    VS,
    FS,
};

pub const ShaderConfig = struct {
    blend_mode: BlendMode = .NONE,
    depth_write_enabled: bool = true,
    depth_compare: CompareFunc = .LESS_EQUAL,
    cull_mode: CullMode = .NONE,
    index_size: IndexSize = .UINT16,
};

pub const ShaderParams = struct {
    // These should probably be a map instead!
    draw_color: [4]f32 = [_]f32 { 1.0, 1.0, 1.0, 1.0 },
    color_override: [4]f32 = [_]f32 { 0.0, 0.0, 0.0, 0.0 },
};

pub const ShaderUniformType = enum(i32) {
    FLOAT,
    VEC2,
    VEC3,
    VEC4,
    INT,
    MAT4,
    VEC4_ARRAY,
    MAT4_ARRAY,
};

pub const ShaderUniform = struct {
    data_float: ?f32 = null,
    data_vec2: ?Vec2 = null,
    data_vec3: ?Vec3 = null,
    // data_vec4: ?Color,
    data_int: ?i32 = null,
    data_mat4: ?Mat4 = null,
    // data_vec4_array: [:0]Mat4,
    data_mat4_array: [:null]?Mat4 = undefined,
    uniform_type: ShaderUniformType,
};

pub const ShaderImpl = sokol_gfx_backend.ShaderImpl;

pub var next_shader_handle: u32 = 0;
pub const Shader = struct {
    handle: u32,
    params: ShaderParams = ShaderParams{},

    // uniform blocks to use for the next draw call
    fs_uniform_blocks: [3]?Anything = [_]?Anything{ null } ** 3,
    vs_uniform_blocks: [3]?Anything = [_]?Anything{ null } ** 3,

    fs_texture_slots: u8 = 1,
    fs_sampler_slots: u8 = 1,
    fs_uniform_slots: u8 = 1,

    vs_texture_slots: u8 = 0,
    vs_sampler_slots: u8 = 0,
    vs_uniform_slots: u8 = 1,

    impl: ShaderImpl,

    /// Create a new shader using the default
    pub fn initDefault(cfg: ShaderConfig) Shader {
        return ShaderImpl.initDefault(cfg);
    }

    // TODO: Add support for loading shaders from built files as well!
    // Sokol supports exporting to multiple shader formats alongside a YAML definition file,
    // we could load that definition and the correct file based on the current backend.

    /// Creates a shader from a shader built in as a zig file
    pub fn initFromBuiltin(cfg: ShaderConfig, comptime builtin: anytype) ?Shader {
        return ShaderImpl.initFromBuiltin(cfg, builtin);
    }

    pub fn cloneFromShader(cfg: ShaderConfig, shader: ?Shader) Shader {
        return ShaderImpl.cloneFromShader(cfg, shader);
    }

    pub fn apply(self: *Shader) void {
        ShaderImpl.apply(self);

        // Reset uniform blocks, to avoid use-after-free
        for(0 .. self.vs_uniform_blocks.len) |i| {
            self.vs_uniform_blocks[i] = null;
        }
        for(0 .. self.fs_uniform_blocks.len) |i| {
            self.fs_uniform_blocks[i] = null;
        }
    }

    pub fn applyUniformBlock(self: *Shader, stage: ShaderStage, slot: u8, data: Anything) void {
        switch(stage) {
            .VS => {
                self.vs_uniform_blocks[slot] = data;
            },
            .FS => {
                self.fs_uniform_blocks[slot] = data;
            },
        }
    }
};

var next_texture_handle: u32 = 0;
pub const Texture = struct {
    width: u32,
    height: u32,
    sokol_image: ?sg.Image,
    handle: u32,

    pub fn init(image: *images.Image) Texture {
        defer next_texture_handle += 1;

        var img_desc: sg.ImageDesc = .{
            .width = @intCast(image.width),
            .height = @intCast(image.height),
            .pixel_format = .RGBA8,
        };

        img_desc.data.subimage[0][0] = sg.asRange(image.raw);

        return Texture {
            .width = image.width,
            .height = image.height,
            .sokol_image = sg.makeImage(img_desc),
            .handle = next_texture_handle,
        };
    }

    pub fn initFromBytes(width: u32, height: u32, image_bytes: anytype) Texture {
        defer next_texture_handle += 1;

        var img_desc: sg.ImageDesc = .{
            .width = @intCast(width),
            .height = @intCast(height),
            .pixel_format = .RGBA8,
        };

        img_desc.data.subimage[0][0] = sg.asRange(image_bytes);

        return Texture {
            .width = width,
            .height = height,
            .sokol_image = sg.makeImage(img_desc),
            .handle = next_texture_handle,
        };
    }
};

pub const MaterialConfig = struct {
    // texture slots for easy binding
    texture_0: ?Texture = null,
    texture_1: ?Texture = null,
    texture_2: ?Texture = null,
    texture_3: ?Texture = null,
    texture_4: ?Texture = null,

    // material options
    cull_mode: CullMode = .BACK,
    filter: FilterMode = .LINEAR,
    blend_mode: BlendMode = .NONE,
    depth_write_enabled: bool = true,
    depth_compare: CompareFunc = .LESS_EQUAL,
    index_size: IndexSize = .UINT32,

    // the parent shader to base us on
    shader: ?Shader = null,
};

pub const MaterialParams = struct {
    draw_color: Color = Color.white(),
    color_override: Color = Color.new(0.0, 0.0, 0.0, 0.0),
    alpha_cutoff: f32 = 0.0,
};

pub const Material = struct {
    textures: [5]?Texture = [_]?Texture{null} ** 5,
    shader: Shader = undefined,
    filter: FilterMode,
    blend_mode: BlendMode,
    depth_write_enabled: bool,
    depth_compare: CompareFunc,
    cull_mode: CullMode,

    params: MaterialParams = MaterialParams{},

    sokol_sampler: ?sg.Sampler = null,

    pub fn init(cfg: MaterialConfig) Material {
        const samplerDesc = convertFilterModeToSamplerDesc(cfg.filter);
        var material = Material {
            .filter = cfg.filter,
            .blend_mode = cfg.blend_mode,
            .depth_write_enabled = cfg.depth_write_enabled,
            .depth_compare = cfg.depth_compare,
            .cull_mode = cfg.cull_mode,
            .sokol_sampler = sg.makeSampler(samplerDesc),
        };

        // ugly!
        if(cfg.texture_0 != null)
            material.textures[0] = cfg.texture_0;
        if(cfg.texture_1 != null)
            material.textures[1] = cfg.texture_1;
        if(cfg.texture_2 != null)
            material.textures[2] = cfg.texture_2;
        if(cfg.texture_3 != null)
            material.textures[3] = cfg.texture_3;
        if(cfg.texture_4 != null)
            material.textures[4] = cfg.texture_4;

        // TODO: Shader loading from files, using Sokol's YAML output

        // make a shader out of our options
        material.shader = Shader.cloneFromShader(.{
            .cull_mode = cfg.cull_mode,
            .blend_mode = cfg.blend_mode,
            .depth_write_enabled = cfg.depth_write_enabled,
            .depth_compare = cfg.depth_compare,
            .index_size = cfg.index_size,
        }, cfg.shader);

        return material;
    }
};

pub const state = struct {
    var debug_draw_bindings: sg.Bindings = .{};
    var debug_draw_pipeline: sg.Pipeline = .{};
    var debug_shader: Shader = undefined;
};

var default_pass_action: sg.PassAction = .{};

pub fn init() !void {
    debug.log("Graphics subsystem starting", .{});

    // Setup debug text rendering
    var text_desc: debugtext.Desc = .{
        .logger = .{ .func = slog.func },
    };
    text_desc.fonts[0] = debugtext.fontOric();
    debugtext.setup(text_desc);

    // Create vertex buffer with debug quad vertices
    state.debug_draw_bindings.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]Vertex{
            .{ .x = 0.0, .y = 1.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 0, .v = 0 },
            .{ .x = 1.0, .y = 1.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 1, .v = 0 },
            .{ .x = 1.0, .y = 0.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 1, .v = 1},
            .{ .x = 0.0, .y = 0.0, .z = 0.0, .color = 0xFFFFFFFF, .u = 0, .v = 1},
        }),
    });

    // Debug quad index buffer
    state.debug_draw_bindings.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(&[_]u16{ 0, 1, 2, 0, 2, 3 }),
    });

    // Create a default sampler for the debug draw bindings
    state.debug_draw_bindings.fs.samplers[0] = sg.makeSampler(.{});

    // Use the default shader for debug drawing
    state.debug_shader = Shader.initDefault(.{});

    // Setup some debug textures
    tex_white = createSolidTexture(0xFFFFFFFF);
    tex_black = createSolidTexture(0xFF000000);
    tex_grey = createSolidTexture(0xFF777777);

    // Set the initial clear color
    default_pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1 },
    };

    debug.log("Graphics subsystem started successfully", .{});
}

pub fn deinit() void {
    debug.log("Graphics subsystem stopping", .{});
}

pub fn startFrame() void {
    // reset debug text
    debugtext.canvas(sapp.widthf() * 0.5, sapp.heightf() * 0.5);
    debugtext.layer(0);

    sg.beginDefaultPass(default_pass_action, sapp.width(), sapp.height());
}

pub fn endFrame() void {
    // draw console text on a new layer
    debugtext.layer(1);
    debug.drawConsole(false);

    // draw any debug text
    debugtext.drawLayer(0);

    // draw the console text over other text
    debug.drawConsoleBackground();
    debugtext.drawLayer(1);

    // flush to the screen!
    sg.endPass();
    sg.commit();
}

pub fn setClearColor(color: Color) void {
    default_pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a },
    };
}

pub fn getProjectionPerspective(fov: f32, near: f32, far: f32) Mat4 {
    const aspect = papp.getAspectRatio();
    return Mat4.persp(fov, aspect, near, far);
}

pub fn getProjectionOrtho(near: f32, far: f32, flip_y: bool) Mat4 {
    if(flip_y) {
        return Mat4.ortho(0.0, sapp.widthf(), sapp.heightf(), 0.0, near, far);
    }
    return Mat4.ortho(0.0, sapp.widthf(), 0.0, sapp.heightf(), near, far);
}

pub fn getProjectionOrthoCustom(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
    return Mat4.ortho(left, right, bottom, top, near, far);
}

pub fn setDebugTextColor4f(r: f32, g: f32, b: f32, a: f32) void {
    debugtext.color4f(r, g, b, a);
}

pub fn setDebugTextColor4b(r: u8, g: u8, b: u8, a: u8) void {
    debugtext.color4b(r, g, b, a);
}

pub fn drawDebugText(x: f32, y: f32, str: [:0]const u8) void {
    debugtext.pos(x * 0.125, y * 0.125);
    debugtext.puts(str);
}

pub fn drawDebugTextChar(x: f32, y: f32, char: u8) void {
    debugtext.pos(x * 0.125, y * 0.125);
    debugtext.putc(char);
}

pub fn setDebugTextScale(x: f32, y: f32) void {
    debugtext.canvas(sapp.widthf() / (x * 2.0), sapp.heightf() / (y * 2.0));
}

pub fn setDebugDrawShaderParams(params: ShaderParams) void {
    state.debug_shader.params = params;
}

// todo: add color to this and to the shader
pub fn drawDebugRectangle(tex: Texture, x: f32, y: f32, width: f32, height: f32, color: Color) void {
    // apply the texture
    state.debug_draw_bindings.fs.images[0] = tex.sokol_image.?;

    // create a view state
    const proj = Mat4.ortho(0.0, sapp.widthf(), 0.0, sapp.heightf(), 0.001, 10.0);
    var view = Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 5.0 }, Vec3.zero(), Vec3.up());

    const translate_vec: Vec3 = Vec3{.x = x, .y = @as(f32, @floatFromInt(getDisplayHeight())) - (y + height), .z = -1.5};
    const scale_vec: Vec3 = Vec3{.x = width, .y = height, .z = 1.0};

    var model = Mat4.identity();
    model = model.mul(Mat4.translate(translate_vec));
    model = model.mul(Mat4.scale(scale_vec));

    const vs_params = shader_default.VsParams{
        .u_projViewMatrix = proj.mul(view),
        .u_modelMatrix = model,
        .u_color = color.toArray(),
    };

    const fs_params = shader_default.FsParams{
        .u_color_override = state.debug_shader.params.color_override,
        .u_alpha_cutoff = 0.0,
    };

    sg.applyPipeline(state.debug_shader.impl.sokol_pipeline.?);
    sg.applyUniforms(.VS, 0, sg.asRange(&vs_params));
    sg.applyUniforms(.FS, 0, sg.asRange(&fs_params));
    sg.applyBindings(state.debug_draw_bindings);

    // draw our quad
    sg.draw(0, 6, 1);
}

pub fn getDisplayWidth() i32 {
   return sapp.width();
}

pub fn getDisplayHeight() i32 {
   return sapp.height();
}

pub fn getDisplayDPIScale() f32 {
    return sapp.dpiScale();
}

/// Draw part of a binding
pub fn drawSubset(bindings: *Bindings, start: u32, end: u32, shader: *Shader) void {
    BindingsImpl.drawSubset(bindings, start, end, shader);
}

/// Draw a whole binding
pub fn draw(bindings: *Bindings, shader: *Shader) void {
    drawSubset(bindings, 0, @intCast(bindings.length), shader);
}

/// Draw a part of a binding, using a material
pub fn drawSubsetWithMaterial(bindings: *Bindings, start: u32, end: u32, material: *Material) void {
    bindings.updateFromMaterial(material);
    drawSubset(bindings, start, end, &material.shader);
}

/// Draw a whole binding, using a material
pub fn drawWithMaterial(bindings: *Bindings, material: *Material) void {
    drawSubsetWithMaterial(bindings, 0, @intCast(bindings.length), material);
}

/// Returns a small 2x2 solid color texture
pub fn createSolidTexture(color: u32) Texture {
    const img = &[2 * 2]u32{
        color, color,
        color, color,
    };
    return Texture.initFromBytes(2, 2, img);
}

/// Returns a 4x4 checkerboard texture for debugging
pub fn createDebugTexture() Texture {
    const img = &[4 * 4]u32{
        0xFF999999, 0xFF555555, 0xFF999999, 0xFF555555,
        0xFF555555, 0xFF999999, 0xFF555555, 0xFF999999,
        0xFF999999, 0xFF555555, 0xFF999999, 0xFF555555,
        0xFF555555, 0xFF999999, 0xFF555555, 0xFF999999,
    };
    return Texture.initFromBytes(4, 4, img);
}

fn convertFilterModeToSamplerDesc(filter: FilterMode) sg.SamplerDesc {
    const filter_mode = if (filter == FilterMode.LINEAR) sg.Filter.LINEAR else sg.Filter.NEAREST;
    return sg.SamplerDesc {
        .min_filter = filter_mode,
        .mag_filter = filter_mode,
        .mipmap_filter = filter_mode,
    };
}

// Taken from sokol_zig gfx, uses this to pass untyped data around
pub fn asAnything(val: anytype) Anything {
    const type_info = @typeInfo(@TypeOf(val));
    switch (type_info) {
        .Pointer => {
            switch (type_info.Pointer.size) {
                .One => return .{ .ptr = val, .size = @sizeOf(type_info.Pointer.child) },
                .Slice => return .{ .ptr = val.ptr, .size = @sizeOf(type_info.Pointer.child) * val.len },
                else => @compileError("FIXME: Pointer type!"),
            }
        },
        .Struct, .Array => {
            @compileError("Structs and arrays must be passed as pointers to asAnything");
        },
        else => {
            @compileError("Cannot convert to range!");
        },
    }
}
