
const std = @import("std");
const debug = @import("../../../debug.zig");
const graphics = @import("../../graphics.zig");
const images = @import("../../../images.zig");
const sokol = @import("sokol");
const shader_default = @import("../../../graphics/shaders/default.glsl.zig");

const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;
const debugtext = sokol.debugtext;

pub const Bindings = graphics.Bindings;
pub const Material = graphics.Material;
pub const Vertex = graphics.Vertex;
pub const Texture = graphics.Texture;
pub const Shader = graphics.Shader;

pub const BindingsImpl = struct {
    sokol_bindings: ?sg.Bindings,
    default_sokol_sampler: sg.Sampler = undefined,

    pub fn init(cfg: graphics.BindingConfig) Bindings {
        var bindingsImpl = BindingsImpl {
            .sokol_bindings = .{},
        };

        var bindings: Bindings = Bindings {
            .length = 0,
            .impl = bindingsImpl,
            .config = cfg,
        };

        // Updatable buffers will need to be created ahead-of-time
        if(cfg.updatable) {
            bindings.impl.sokol_bindings.?.vertex_buffers[0] = sg.makeBuffer(.{
                .usage = .STREAM,
                .size = cfg.vert_len * @sizeOf(Vertex),
            });
            bindings.impl.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
                .usage = .STREAM,
                .type = .INDEXBUFFER,
                .size = cfg.index_len * @sizeOf(u32),
            });
        }

        // maybe have a default material instead?
        const samplerDesc = convertFilterModeToSamplerDesc(.NEAREST);
        bindings.impl.default_sokol_sampler = sg.makeSampler(samplerDesc);
        bindings.impl.sokol_bindings.?.fs.samplers[0] = bindings.impl.default_sokol_sampler;

        return bindings;
    }

    pub fn set(self: *Bindings, vertices: anytype, indices: anytype, length: usize) void {
        if(self.impl.sokol_bindings == null) {
            return;
        }

        self.length = length;
        self.impl.sokol_bindings.?.vertex_buffers[0] = sg.makeBuffer(.{
            .data = sg.asRange(vertices),
        });
        self.impl.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
            .type = .INDEXBUFFER,
            .data = sg.asRange(indices),
        });
    }

    pub fn update(self: *Bindings, vertices: anytype, indices: anytype, vert_len: usize, index_len: usize) void {
        if(self.impl.sokol_bindings == null) {
            return;
        }

        self.length = index_len;

        if(index_len == 0)
            return;

        sg.updateBuffer(self.impl.sokol_bindings.?.vertex_buffers[0], sg.asRange(vertices[0..vert_len]));
        sg.updateBuffer(self.impl.sokol_bindings.?.index_buffer, sg.asRange(indices[0..index_len]));
    }

    /// Sets the texture that will be used to draw this binding
    pub fn setTexture(self: *Bindings, texture: Texture) void {
        if(texture.sokol_image == null)
            return;

        // set the texture to the default fragment shader image slot
        self.impl.sokol_bindings.?.fs.images[0] = texture.sokol_image.?;
    }

    pub fn updateFromMaterial(self: *Bindings, material: *Material) void {
        for(0..material.textures.len) |i| {
            if(material.textures[i] != null)
                self.impl.sokol_bindings.?.fs.images[i] = material.textures[i].?.sokol_image.?;
        }

        // how many samplers should we support?
        self.impl.sokol_bindings.?.fs.samplers[0] = material.sokol_sampler.?;

        // also set shader uniforms here?
    }

    /// Destroy our binding
    pub fn destroy(self: *Bindings) void {
        sg.destroyBuffer(self.impl.sokol_bindings.?.vertex_buffers[0]);
        sg.destroyBuffer(self.impl.sokol_bindings.?.index_buffer);
        sg.destroySampler(self.impl.default_sokol_sampler);
    }

    /// Resize buffers used by our binding. Will destroy buffers and recreate them!
    pub fn resize(self: *Bindings, vertex_len: usize, index_len: usize) void {
        if(!self.config.updatable)
            return;

        // debug.log("Resizing buffer! {}x{}", .{vertex_len, index_len});

        // destroy old buffers
        sg.destroyBuffer(self.impl.sokol_bindings.?.vertex_buffers[0]);
        sg.destroyBuffer(self.impl.sokol_bindings.?.index_buffer);

        // create new buffers
        self.impl.sokol_bindings.?.vertex_buffers[0] = sg.makeBuffer(.{
            .usage = .STREAM,
            .size = vertex_len * @sizeOf(Vertex),
        });
        self.impl.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
            .usage = .STREAM,
            .type = .INDEXBUFFER,
            .size = index_len * @sizeOf(u32),
        });
    }

    pub fn drawSubset(bindings: *Bindings, start: u32, end: u32, shader: *Shader) void {
        if(bindings.impl.sokol_bindings == null or shader.impl.sokol_pipeline == null)
            return;

        shader.apply();

        sg.applyBindings(bindings.impl.sokol_bindings.?);
        sg.draw(start, end, 1);
    }
};

pub const ShaderImpl = struct {
    sokol_pipeline: ?sg.Pipeline,
    sokol_shader_desc: sg.ShaderDesc,

    /// Create a new shader using the default
    pub fn initDefault(cfg: graphics.ShaderConfig) Shader {
        const shader_desc = shader_default.defaultShaderDesc(sg.queryBackend());
        return initSokolShader(cfg, shader_desc);
    }

    /// Creates a shader from a shader built in as a zig file
    pub fn initFromBuiltin(cfg: graphics.ShaderConfig, comptime builtin: anytype) ?Shader {
        const shader_desc_fn = getBuiltinSokolCreateFunction(builtin);
        if(shader_desc_fn == null)
            return null;

        return initSokolShader(cfg, shader_desc_fn.?(sg.queryBackend()));
    }

    pub fn cloneFromShader(cfg: graphics.ShaderConfig, shader: ?Shader) Shader {
        if(shader == null)
            return initDefault(cfg);

        return initSokolShader(cfg, shader.?.impl.sokol_shader_desc);
    }

    /// Find the function in the builtin that can actually make the ShaderDesc
    fn getBuiltinSokolCreateFunction(comptime builtin: anytype) ?fn(sg.Backend) sg.ShaderDesc {
        comptime {
            const decls = @typeInfo(builtin).Struct.decls;
            for (decls) |d| {
                const field = @field(builtin, d.name);
                const field_type = @typeInfo(@TypeOf(field));
                if(field_type == .Fn) {
                    const fn_info = field_type.Fn;
                    if(fn_info.return_type == sg.ShaderDesc) {
                        return field;
                    }
                }
            }
        }
        return null;
    }

    /// Create a shader from a Sokol Shader Description - useful for loading built-in shaders
    pub fn initSokolShader(cfg: graphics.ShaderConfig, shader_desc: sg.ShaderDesc) Shader {
        const shader = sg.makeShader(shader_desc);

        // TODO: Fill in the rest of these values!
        var num_fs_images: u8 = 0;
        for(0..5) |i| {
            if(shader_desc.fs.images[i].used) {
                num_fs_images += 1;
            } else {
                break;
            }
        }

        var pipe_desc: sg.PipelineDesc = .{
            .index_type = if(cfg.index_size == .UINT16) .UINT16 else .UINT32,
            .shader = shader,
            .depth = .{
                .compare = convertCompareFunc(cfg.depth_compare),
                .write_enabled = cfg.depth_write_enabled,
            },
            .cull_mode = convertCullMode(cfg.cull_mode),
        };

        // todo: get these from the ShaderConfig, use intermediate enums
        pipe_desc.layout.attrs[shader_default.ATTR_vs_pos].format = .FLOAT3;
        pipe_desc.layout.attrs[shader_default.ATTR_vs_color0].format = .UBYTE4N;
        pipe_desc.layout.attrs[shader_default.ATTR_vs_texcoord0].format = .FLOAT2;

        // apply blending values
        pipe_desc.colors[0].blend = convertBlendMode(cfg.blend_mode);

        defer graphics.next_shader_handle += 1;
        return Shader {
            .impl = .{
                .sokol_pipeline = sg.makePipeline(pipe_desc),
                .sokol_shader_desc = shader_desc,
            },
            .handle = graphics.next_shader_handle,
            .fs_texture_slots = num_fs_images,
        };
    }

    pub fn apply(self: *Shader) void {
        if(self.impl.sokol_pipeline == null)
            return;

        sg.applyPipeline(self.impl.sokol_pipeline.?);

        // apply uniform blocks
        for(self.vs_uniform_blocks, 0..) |block, i| {
            if(block) |b|
                sg.applyUniforms(.VS, @intCast(i), sg.Range{ .ptr = b.ptr, .size = b.size });
        }

        for(self.fs_uniform_blocks, 0..) |block, i| {
            if(block) |b|
                sg.applyUniforms(.FS, @intCast(i), sg.Range{ .ptr = b.ptr, .size = b.size });
        }
    }

    pub fn setParams(self: *Shader, params: graphics.ShaderParams) void {
        self.params = params;
    }
};

/// Converts our FilterMode to a sokol sampler description
fn convertFilterModeToSamplerDesc(filter: graphics.FilterMode) sg.SamplerDesc {
    const filter_mode = if (filter == .LINEAR) sg.Filter.LINEAR else sg.Filter.NEAREST;
    return sg.SamplerDesc {
        .min_filter = filter_mode,
        .mag_filter = filter_mode,
        .mipmap_filter = filter_mode,
    };
}

/// Converts our CompareFunc enum to a Sokol CompareFunc enum
fn convertCompareFunc(func: graphics.CompareFunc) sg.CompareFunc {
    // Our enums match up, so this is easy!
    return @enumFromInt(@intFromEnum(func));
}

/// Converts our CullMode enum to a Sokol CullMode enum
fn convertCullMode(mode: graphics.CullMode) sg.CullMode {
    switch(mode) {
        .NONE => {
            return sg.CullMode.NONE;
        },
        .BACK => {
            return sg.CullMode.FRONT;
        },
        .FRONT => {
            return sg.CullMode.BACK;
        }
    }
}

/// Converts our BlendMode enum to a Sokol BlendState struct
fn convertBlendMode(mode: graphics.BlendMode) sg.BlendState {
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
