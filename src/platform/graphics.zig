const debug = @import("../debug.zig");
const images = @import("../images.zig");

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;
const debugtext = sokol.debugtext;

// compile built-in shaders via:
// ./sokol-shdc -i assets/shaders/default.glsl -o src/graphics/shaders/default.glsl.zig -l glsl330:metal_macos:hlsl4 -f sokol_zig
const shaders = @import("../graphics/shaders/default.glsl.zig");

const Vec2 = @import("../math.zig").Vec2;
const Vec3 = @import("../math.zig").Vec3;
const Mat4 = @import("../math.zig").Mat4;

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

pub const Vertex = struct {
    x: f32,
    y: f32,
    z: f32,
    color: u32,
    u: f32,
    v: f32,

    pub fn mulMat4(left: Vertex, right: Mat4) Vertex {
        var ret = left;
        const vec = Vec3.mulMat4(Vec3{.x = left.x, .y = left.y, .z = left.z}, right);
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
};

pub const BindingConfig = struct {
    updatable: bool = false,
    vert_len: usize = 3200,
    index_len: usize = 3200,
};

pub const Bindings = struct {
    length: usize,
    sokol_bindings: ?sg.Bindings,
    config: BindingConfig,

    pub fn init(cfg: BindingConfig) Bindings {
        var bindings: Bindings = Bindings {
            .length = 0,
            .sokol_bindings = .{},
            .config = cfg,
        };

        // Updatable buffers will need to be created ahead-of-time
        if(cfg.updatable) {
            bindings.sokol_bindings.?.vertex_buffers[0] = sg.makeBuffer(.{
                .usage = .STREAM,
                .size = cfg.vert_len * @sizeOf(Vertex),
            });
            bindings.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
                .usage = .STREAM,
                .type = .INDEXBUFFER,
                .size = cfg.index_len * @sizeOf(u16),
            });
        }

        // Make a sampler for our bindings
        bindings.sokol_bindings.?.fs.samplers[shaders.SLOT_smp] = sg.makeSampler(.{});

        return bindings;
    }

    /// Creates new buffers to hold these vertices and indices
    pub fn set(self: *Bindings, vertices: anytype, indices: anytype, length: usize) void {
        if(self.sokol_bindings == null) {
            return;
        }

        self.length = length;
        self.sokol_bindings.?.vertex_buffers[0] = sg.makeBuffer(.{
            .data = sg.asRange(vertices),
        });
        self.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
            .type = .INDEXBUFFER,
            .data = sg.asRange(indices),
        });
    }

    /// Updates the existing buffers with new data
    pub fn update(self: *Bindings, vertices: anytype, indices: anytype, vert_len: usize, index_len: usize) void {
        if(self.sokol_bindings == null) {
            return;
        }

        self.length = index_len;

        if(index_len == 0)
            return;

        sg.updateBuffer(self.sokol_bindings.?.vertex_buffers[0], sg.asRange(vertices[0..vert_len]));
        sg.updateBuffer(self.sokol_bindings.?.index_buffer, sg.asRange(indices[0..index_len]));
    }

    /// Sets the texture that will be used to draw this binding
    pub fn setTexture(self: *Bindings, texture: Texture) void {
        if(texture.sokol_image == null)
            return;

        self.sokol_bindings.?.fs.images[shaders.SLOT_tex] = texture.sokol_image.?;
    }

    /// Destroy our binding
    pub fn destroy(self: *Bindings) void {
        sg.destroyBuffer(self.sokol_bindings.?.vertex_buffers[0]);
        sg.destroyBuffer(self.sokol_bindings.?.index_buffer);
        sg.destroySampler(self.sokol_bindings.?.fs.samplers[shaders.SLOT_smp]);
    }

    /// Resize buffers used by our binding. Will destroy buffers and recreate them!
    pub fn resize(self: *Bindings, vertex_len: usize, index_len: usize) void {
        if(!self.config.updatable)
            return;

        // debug.log("Resizing buffer! {}x{}", .{vertex_len, index_len});

        // destroy old buffers
        sg.destroyBuffer(self.sokol_bindings.?.vertex_buffers[0]);
        sg.destroyBuffer(self.sokol_bindings.?.index_buffer);

        // create new buffers
        self.sokol_bindings.?.vertex_buffers[0] = sg.makeBuffer(.{
            .usage = .STREAM,
            .size = vertex_len * @sizeOf(Vertex),
        });
        self.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
            .usage = .STREAM,
            .type = .INDEXBUFFER,
            .size = index_len * @sizeOf(u16),
        });
    }
};

pub const ShaderConfig = struct {
    // TODO: Put depth, index type, attributes, etc, here
    blend_mode: BlendMode = .NONE,
    depth_write_enabled: bool = true,
    depth_compare: CompareFunc = .LESS_EQUAL,
};

var next_shader_handle: u32 = 0;
pub const Shader = struct {
    sokol_pipeline: ?sg.Pipeline,
    handle: u32,

    pub fn init(cfg: ShaderConfig) Shader {
        // Just use the default shader for now. Maybe use an enum to switch between builtin shaders?
        const shader = sg.makeShader(shaders.defaultShaderDesc(sg.queryBackend()));

        var pipe_desc: sg.PipelineDesc = .{
            .index_type = .UINT16,
            .shader = shader,
            .depth = .{
                .compare = convertCompareFunc(cfg.depth_compare),
                .write_enabled = cfg.depth_write_enabled,
            }
        };

        // todo: get these from the ShaderConfig, use intermediate enums
        pipe_desc.layout.attrs[shaders.ATTR_vs_pos].format = .FLOAT3;
        pipe_desc.layout.attrs[shaders.ATTR_vs_color0].format = .UBYTE4N;
        pipe_desc.layout.attrs[shaders.ATTR_vs_texcoord0].format = .FLOAT2;

        // apply blending values
        pipe_desc.colors[0].blend = convertBlendMode(cfg.blend_mode);

        defer next_shader_handle += 1;
        return Shader { .sokol_pipeline = sg.makePipeline(pipe_desc), .handle = next_shader_handle };
    }

    pub fn apply(self: *Shader) void {
        if(self.sokol_pipeline == null)
            return;

        const vs_params = shaders.VsParams{
            .mvp = Mat4.mul(Mat4.mul(state.projection, state.view), state.model),
            .in_color = state.draw_color,
        };

        sg.applyPipeline(self.sokol_pipeline.?);
        sg.applyUniforms(.VS, shaders.SLOT_vs_params, sg.asRange(&vs_params));
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

const state = struct {
    var debug_draw_bindings: sg.Bindings = .{};
    var debug_draw_pipeline: sg.Pipeline = .{};

    // 3d view matrices
    var projection = Mat4.persp(60.0, 1.28, 0.01, 50.0);
    var view: Mat4 = Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 3.0 }, Vec3.zero(), Vec3.up());
    var model: Mat4 = Mat4.zero();

    var draw_color: [4]f32 = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
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

    // Setup some debug textures
    tex_white = createSolidTexture(0xFFFFFFFF);
    tex_black = createSolidTexture(0xFF000000);
    tex_grey = createSolidTexture(0xFF333333);

    setDebugDrawTexture(tex_white);

    // Create a default sampler for the debug draw bindings
    state.debug_draw_bindings.fs.samplers[shaders.SLOT_smp] = sg.makeSampler(.{});

    // Create a debug shader and pipeline object
    const shader = sg.makeShader(shaders.defaultShaderDesc(sg.queryBackend()));
    var pipe_desc: sg.PipelineDesc = .{
        .shader = shader,
        .depth = .{
            .compare = .LESS_EQUAL,
            .write_enabled = true,
        }
    };
    pipe_desc.layout.attrs[shaders.ATTR_vs_pos].format = .FLOAT3;
    pipe_desc.layout.attrs[shaders.ATTR_vs_color0].format = .UBYTE4N;
    pipe_desc.layout.attrs[shaders.ATTR_vs_texcoord0].format = .FLOAT2;

    pipe_desc.index_type = .UINT16;
    state.debug_draw_pipeline = sg.makePipeline(pipe_desc);

    // Set the initial clear color
    default_pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1 },
    };

    // Set our initial view projection
    setProjectionPerspective(60.0, 0.01, 50.0);

    // Setup initial view state
    state.view = Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 3.0 }, Vec3.zero(), Vec3.up());

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

pub fn setDrawColor(color: Color) void {
    state.draw_color = [_]f32 { color.r, color.g, color.b, color.a };
}

pub fn setView(view_matrix: Mat4, model_matrix: Mat4) void {
    state.view = view_matrix;
    state.model = model_matrix;
}

pub fn setProjectionPerspective(fov: f32, near: f32, far: f32) void {
    const aspect = sapp.widthf() / sapp.heightf();
    state.projection = Mat4.persp(fov, aspect, near, far);
}

pub fn setProjectionOrtho(near: f32, far: f32, flip_y: bool) void {
    if(flip_y) {
        state.projection = Mat4.ortho(0.0, sapp.widthf(), sapp.heightf(), 0.0, near, far);
        return;
    }
    state.projection = Mat4.ortho(0.0, sapp.widthf(), 0.0, sapp.heightf(), near, far);
}

pub fn setProjectionOrthoCustom(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) void {
    state.projection = Mat4.ortho(left, right, bottom, top, near, far);
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

pub fn setDebugDrawTexture(texture: Texture) void {
    state.debug_draw_bindings.fs.images[shaders.SLOT_tex] = texture.sokol_image.?;
}

// todo: add color to this and to the shader
pub fn drawDebugRectangle(x: f32, y: f32, width: f32, height: f32, color: Color) void {
    // create a view state
    const proj = Mat4.ortho(0.0, sapp.widthf(), 0.0, sapp.heightf(), 0.001, 10.0);
    var view = Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 5.0 }, Vec3.zero(), Vec3.up());

    const translate_vec: Vec3 = Vec3{.x = x, .y = @as(f32, @floatFromInt(getDisplayHeight())) - (y + height), .z = -1.5};
    const scale_vec: Vec3 = Vec3{.x = width, .y = height, .z = 1.0};

    var model = Mat4.identity();
    model = Mat4.mul(model, Mat4.translate(translate_vec));
    model = Mat4.mul(model, Mat4.scale(scale_vec));

    const vs_params = shaders.VsParams{
        .mvp = Mat4.mul(Mat4.mul(proj, view), model),
        .in_color = [_]f32 { color.r, color.g, color.b, color.a },
    };

    // set the debug draw bindings
    sg.applyPipeline(state.debug_draw_pipeline);
    sg.applyBindings(state.debug_draw_bindings);
    sg.applyUniforms(.VS, shaders.SLOT_vs_params, sg.asRange(&vs_params));

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

pub fn drawSubset(start: u32, end: u32, bindings: *Bindings, shader: *Shader) void {
    if(bindings.sokol_bindings == null or shader.sokol_pipeline == null)
        return;

    shader.apply();

    sg.applyBindings(bindings.sokol_bindings.?);
    sg.draw(start, end, 1);
}

pub fn draw(bindings: *Bindings, shader: *Shader) void {
    // Draw the whole buffer
    drawSubset(0, @intCast(bindings.length), bindings, shader);
}

fn createSolidTexture(color: u32) Texture {
    const img = &[2 * 2]u32{
        color, color,
        color, color,
    };
    return Texture.initFromBytes(2, 2, img);
}

/// Converts our BlendMode enum to a Sokol BlendState struct
fn convertBlendMode(mode: BlendMode) sg.BlendState {
    switch(mode) {
        .NONE => {
            return sg.BlendState{ };
        },
        .BLEND => {
            return sg.BlendState{
                .enabled = true,
                .src_factor_rgb = sg.BlendFactor.SRC_ALPHA,
                .dst_factor_rgb = sg.BlendFactor.ONE_MINUS_SRC_ALPHA,
                .op_rgb = sg.BlendOp.ADD,
                .src_factor_alpha = sg.BlendFactor.ONE,
                .dst_factor_alpha = sg.BlendFactor.ONE_MINUS_SRC_ALPHA,
                .op_alpha = sg.BlendOp.ADD,
            };
        },
        .ADD => {
            return sg.BlendState{
                .enabled = true,
                .src_factor_rgb = sg.BlendFactor.SRC_ALPHA,
                .dst_factor_rgb = sg.BlendFactor.ONE,
                .op_rgb = sg.BlendOp.ADD,
                .src_factor_alpha = sg.BlendFactor.ZERO,
                .dst_factor_alpha = sg.BlendFactor.ONE,
                .op_alpha = sg.BlendOp.ADD,
            };
        },
        .MUL => {
            return sg.BlendState{
                .enabled = true,
                .src_factor_rgb = sg.BlendFactor.DST_COLOR,
                .dst_factor_rgb = sg.BlendFactor.ONE_MINUS_SRC_ALPHA,
                .op_rgb = sg.BlendOp.ADD,
                .src_factor_alpha = sg.BlendFactor.DST_ALPHA,
                .dst_factor_alpha = sg.BlendFactor.ONE_MINUS_SRC_ALPHA,
                .op_alpha = sg.BlendOp.ADD,
            };
        },
        .MOD => {
            return sg.BlendState{
                .enabled = true,
                .src_factor_rgb = sg.BlendFactor.DST_COLOR,
                .dst_factor_rgb = sg.BlendFactor.ZERO,
                .op_rgb = sg.BlendOp.ADD,
                .src_factor_alpha = sg.BlendFactor.ZERO,
                .dst_factor_alpha = sg.BlendFactor.ONE,
                .op_alpha = sg.BlendOp.ADD,
            };
        },
    }
}

/// Converts our CompareFunc enum to a Sokol CompareFunc struct
fn convertCompareFunc(func: CompareFunc) sg.CompareFunc {
    // Our enums match up, so this is easy!
    return @enumFromInt(@intFromEnum(func));
}
