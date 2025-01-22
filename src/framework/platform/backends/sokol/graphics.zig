const std = @import("std");
const debug = @import("../../../debug.zig");
const graphics = @import("../../graphics.zig");
const mem = @import("../../../mem.zig");
const images = @import("../../../images.zig");
const shaders = @import("../../../graphics/shaders.zig");
const sokol = @import("sokol");
const shader_default = @import("../../../graphics/shaders/default.glsl.zig");

const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const debugtext = sokol.debugtext;

pub const Bindings = graphics.Bindings;
pub const Material = graphics.Material;
pub const Vertex = graphics.Vertex;
pub const Texture = graphics.Texture;
pub const Shader = graphics.Shader;

// the list of layouts to automatically create Pipelines for
const common_vertex_layouts = graphics.getCommonVertexLayouts();

const ShaderInitError = error{
    ShaderNotFound,
};

pub const BindingsImpl = struct {
    sokol_bindings: ?sg.Bindings,
    default_sokol_sampler: sg.Sampler = undefined,
    index_type_size: u8 = @sizeOf(u32),

    pub fn init(cfg: graphics.BindingConfig) Bindings {
        const bindingsImpl = BindingsImpl{
            .sokol_bindings = .{},
            .index_type_size = if (cfg.vertex_layout.index_size == .UINT16) @sizeOf(u16) else @sizeOf(u32),
        };

        var bindings: Bindings = Bindings{
            .length = 0,
            .impl = bindingsImpl,
            .config = cfg,
            .vertex_layout = cfg.vertex_layout,
        };

        // Updatable buffers will need to be created ahead-of-time
        if (cfg.updatable) {
            for (cfg.vertex_layout.attributes, 0..) |attr, idx| {
                bindings.impl.sokol_bindings.?.vertex_buffers[idx] = sg.makeBuffer(.{
                    .usage = .STREAM,
                    .size = cfg.vert_len * attr.item_size,
                });
            }

            if (cfg.vertex_layout.has_index_buffer) {
                bindings.impl.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
                    .usage = .STREAM,
                    .type = .INDEXBUFFER,
                    .size = cfg.index_len * bindingsImpl.index_type_size,
                });
            }
        }

        // maybe have a default material instead?
        const samplerDesc = convertFilterModeToSamplerDesc(.NEAREST);
        bindings.impl.default_sokol_sampler = sg.makeSampler(samplerDesc);
        bindings.impl.sokol_bindings.?.fs.samplers[0] = bindings.impl.default_sokol_sampler;

        return bindings;
    }

    pub fn set(self: *Bindings, vertices: anytype, indices: anytype, opt_normals: anytype, opt_tangents: anytype, length: usize) void {
        if (self.impl.sokol_bindings == null) {
            return;
        }

        self.length = length;

        for (self.config.vertex_layout.attributes, 0..) |attr, idx| {
            self.impl.sokol_bindings.?.vertex_buffers[idx] = sg.makeBuffer(.{
                .data = switch (attr.binding) {
                    .VERT_PACKED => sg.asRange(vertices),
                    .VERT_NORMALS => sg.asRange(opt_normals),
                    .VERT_TANGENTS => sg.asRange(opt_tangents),
                    else => sg.asRange(vertices),
                },
            });
        }

        if (self.config.vertex_layout.has_index_buffer) {
            self.impl.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
                .type = .INDEXBUFFER,
                .data = sg.asRange(indices),
            });
        }
    }

    pub fn setWithJoints(self: *Bindings, vertices: anytype, indices: anytype, opt_normals: anytype, opt_tangents: anytype, opt_joints: anytype, opt_weights: anytype, length: usize) void {
        if (self.impl.sokol_bindings == null) {
            return;
        }

        self.length = length;

        for (self.config.vertex_layout.attributes, 0..) |attr, idx| {
            self.impl.sokol_bindings.?.vertex_buffers[idx] = sg.makeBuffer(.{
                .data = switch (attr.binding) {
                    .VERT_PACKED => sg.asRange(vertices),
                    .VERT_NORMALS => sg.asRange(opt_normals),
                    .VERT_TANGENTS => sg.asRange(opt_tangents),
                    .VERT_JOINTS => sg.asRange(opt_joints),
                    .VERT_WEIGHTS => sg.asRange(opt_weights),
                },
            });
        }

        if (self.config.vertex_layout.has_index_buffer) {
            self.impl.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
                .type = .INDEXBUFFER,
                .data = sg.asRange(indices),
            });
        }
    }

    pub fn update(self: *Bindings, vertices: anytype, indices: anytype, vert_len: usize, index_len: usize) void {
        if (self.impl.sokol_bindings == null) {
            return;
        }

        self.length = index_len;

        if (index_len == 0)
            return;

        sg.updateBuffer(self.impl.sokol_bindings.?.vertex_buffers[0], sg.asRange(vertices[0..vert_len]));
        sg.updateBuffer(self.impl.sokol_bindings.?.index_buffer, sg.asRange(indices[0..index_len]));

        // TODO: Update normals and tangents as well, if available
    }

    /// Sets the texture that will be used to draw this binding
    pub fn setTexture(self: *Bindings, texture: Texture) void {
        if (texture.sokol_image == null)
            return;

        // set the texture to the default fragment shader image slot
        self.impl.sokol_bindings.?.fs.images[0] = texture.sokol_image.?;
    }

    pub fn updateFromMaterial(self: *Bindings, material: *Material) void {
        for (0..material.state.textures.len) |i| {
            if (material.state.textures[i] != null)
                self.impl.sokol_bindings.?.fs.images[i] = material.state.textures[i].?.sokol_image.?;
        }

        // bind samplers
        for (material.state.sokol_samplers, 0..) |sampler, i| {
            if (sampler) |s|
                self.impl.sokol_bindings.?.fs.samplers[i] = s;
        }

        // also set shader uniforms here?
    }

    /// Destroy our binding
    pub fn destroy(self: *Bindings) void {
        for (self.config.vertex_layout.attributes, 0..) |_, idx| {
            sg.destroyBuffer(self.impl.sokol_bindings.?.vertex_buffers[idx]);
        }

        if (self.config.vertex_layout.has_index_buffer)
            sg.destroyBuffer(self.impl.sokol_bindings.?.index_buffer);

        sg.destroySampler(self.impl.default_sokol_sampler);
    }

    /// Resize buffers used by our binding. Will destroy buffers and recreate them!
    pub fn resize(self: *Bindings, vertex_len: usize, index_len: usize) void {
        if (!self.config.updatable)
            return;

        // debug.log("Resizing buffer! {}x{}", .{vertex_len, index_len});

        const vert_layout = self.config.vertex_layout;

        // destory the old index buffer
        if (vert_layout.has_index_buffer)
            sg.destroyBuffer(self.impl.sokol_bindings.?.index_buffer);

        // destroy all the old vertex buffers
        for (vert_layout.attributes, 0..) |_, idx| {
            sg.destroyBuffer(self.impl.sokol_bindings.?.vertex_buffers[idx]);
        }

        // create new index buffer
        if (vert_layout.has_index_buffer) {
            self.impl.sokol_bindings.?.index_buffer = sg.makeBuffer(.{
                .usage = .STREAM,
                .type = .INDEXBUFFER,
                .size = index_len * self.impl.index_type_size,
            });
        }

        // create new vertex buffers
        for (vert_layout.attributes, 0..) |attr, idx| {
            self.impl.sokol_bindings.?.vertex_buffers[idx] = sg.makeBuffer(.{
                .usage = .STREAM,
                .size = vertex_len * attr.item_size,
            });
        }
    }

    pub fn drawSubset(bindings: *Bindings, start: u32, end: u32, shader: *Shader) void {
        if (bindings.impl.sokol_bindings == null)
            return;

        const applied_shader = shader.apply(bindings.vertex_layout);
        if (!applied_shader) {
            debug.warning("Could not draw!", .{});
            return;
        }

        sg.applyBindings(bindings.impl.sokol_bindings.?);
        sg.draw(start, end, 1);
    }
};

pub const PipelineBinding = struct {
    sokol_pipeline: sg.Pipeline,
    layout: graphics.VertexLayout,
};

pub const ShaderImpl = struct {
    sokol_shader: sg.Shader,
    sokol_shader_desc: sg.ShaderDesc,
    cfg: graphics.ShaderConfig,

    // Shader instances do not own their sokol_shader, instead they share it with a parent Shader
    is_instance: bool = false,

    // One shader can have many pipelines, so different VertexLayouts can apply it
    sokol_pipelines: std.ArrayList(PipelineBinding),

    /// Create a new shader using the default
    pub fn initDefault(cfg: graphics.ShaderConfig) !Shader {
        return initFromBuiltin(cfg, shader_default);
    }

    /// Creates a shader from a shader built in as a zig file
    pub fn initFromBuiltin(cfg: graphics.ShaderConfig, comptime builtin: anytype) !Shader {
        const shader_desc_fn = getBuiltinSokolCreateFunction(builtin);
        if (shader_desc_fn == null) {
            debug.log("Shader builtin not found!", .{});
            return ShaderInitError.ShaderNotFound;
        }

        return initSokolShader(cfg, shader_desc_fn.?(sg.queryBackend()));
    }

    fn terminateString(allocator: std.mem.Allocator, in_string: []const u8) ![:0]const u8 {
        var terminated_value = try allocator.alloc(u8, in_string.len + 1);
        terminated_value[in_string.len] = 0;
        std.mem.copyForwards(u8, terminated_value, in_string);
        return terminated_value[0..in_string.len :0];
    }

    fn stringUniformTypeToSokolType(string: []const u8) sg.UniformType {
        if (std.mem.eql(u8, string, "float"))
            return .FLOAT;
        if (std.mem.eql(u8, string, "vec2"))
            return .FLOAT2;
        if (std.mem.eql(u8, string, "vec3"))
            return .FLOAT3;
        if (std.mem.eql(u8, string, "vec4"))
            return .FLOAT4;
        if (std.mem.eql(u8, string, "int"))
            return .INT;
        if (std.mem.eql(u8, string, "ivec2"))
            return .INT2;
        if (std.mem.eql(u8, string, "ivec3"))
            return .INT3;
        if (std.mem.eql(u8, string, "ivec4"))
            return .INT4;
        if (std.mem.eql(u8, string, "mat4"))
            return .MAT4;

        return .INVALID;
    }

    fn stringImageSampleTypeToSokolType(string: []const u8) sg.ImageSampleType {
        if (std.mem.eql(u8, string, "float"))
            return .FLOAT;
        if (std.mem.eql(u8, string, "depth"))
            return .DEPTH;
        if (std.mem.eql(u8, string, "sint"))
            return .SINT;
        if (std.mem.eql(u8, string, "uint"))
            return .UINT;
        if (std.mem.eql(u8, string, "unfilterable-float"))
            return .UNFILTERABLE_FLOAT;

        return .FLOAT;
    }

    fn stringImageTypeToSokolType(string: []const u8) sg.ImageType {
        if (std.mem.eql(u8, string, "2d"))
            return ._2D;
        if (std.mem.eql(u8, string, "cube"))
            return .CUBE;
        if (std.mem.eql(u8, string, "3d"))
            return ._3D;
        if (std.mem.eql(u8, string, "array"))
            return .ARRAY;

        return ._2D;
    }

    fn stringSampleTypeToSokolType(string: []const u8) sg.SamplerType {
        if (std.mem.eql(u8, string, "filtering"))
            return .FILTERING;
        if (std.mem.eql(u8, string, "nonfiltering"))
            return .NONFILTERING;
        if (std.mem.eql(u8, string, "comparison"))
            return .COMPARISON;

        return .FILTERING;
    }

    fn stringBool(string: []const u8) bool {
        if (std.mem.eql(u8, string, "true"))
            return true;
        return false;
    }

    /// Creates a shader from a ShaderDefinition struct
    pub fn initFromShaderInfo(cfg: graphics.ShaderConfig, shader_info: shaders.ShaderInfo) !Shader {
        var arena = std.heap.ArenaAllocator.init(mem.getAllocator());
        defer arena.deinit();
        const allocator = arena.allocator();

        // const backend = sg.queryBackend();
        // debug.log("Graphics backend: {any}", .{backend});

        var vs_images_hashmap: std.StringHashMap(u32) = std.StringHashMap(u32).init(allocator);
        var vs_samplers_hashmap: std.StringHashMap(u32) = std.StringHashMap(u32).init(allocator);
        var fs_images_hashmap: std.StringHashMap(u32) = std.StringHashMap(u32).init(allocator);
        var fs_samplers_hashmap: std.StringHashMap(u32) = std.StringHashMap(u32).init(allocator);

        // Assume there is only one shader program for now, that appears to be true.
        const shader_program = shader_info.shader_def.programs[0];

        const vs_entry = try terminateString(allocator, shader_program.vs.entry_point);
        const fs_entry = try terminateString(allocator, shader_program.fs.entry_point);

        var desc: sg.ShaderDesc = .{};
        desc.label = "shader"; // does this matter?

        // vertex shader defs
        desc.vs.source = shader_info.vs_source.ptr;
        desc.vs.entry = vs_entry.ptr;

        // attributes (needed for sokol's hlsl validation - not used besides that?)
        if (shader_program.vs.inputs) |inputs| {
            for (inputs) |input| {
                desc.attrs[input.slot].sem_index = @intCast(input.sem_index);
                desc.attrs[input.slot].sem_name = input.sem_name.ptr;
                desc.attrs[input.slot].name = input.name.ptr;
            }
        }

        // vs uniforms
        if (shader_program.vs.uniform_blocks) |uniform_blocks| {
            for (uniform_blocks) |block| {
                desc.vs.uniform_blocks[block.slot].size = block.size;
                desc.vs.uniform_blocks[block.slot].layout = .STD140;

                for (block.uniforms, 0..) |uniform, i| {
                    const uniform_name = try terminateString(allocator, uniform.name);
                    desc.vs.uniform_blocks[block.slot].uniforms[i].name = uniform_name.ptr;
                    desc.vs.uniform_blocks[block.slot].uniforms[i].type = stringUniformTypeToSokolType(uniform.type);
                    desc.vs.uniform_blocks[block.slot].uniforms[i].array_count = uniform.array_count;
                }
            }
        }

        // vs images
        if (shader_program.vs.images) |imgs| {
            for (imgs) |img| {
                desc.vs.images[img.slot].used = true;
                desc.vs.images[img.slot].multisampled = stringBool(img.multisampled);
                desc.vs.images[img.slot].image_type = stringImageTypeToSokolType(img.type);
                desc.vs.images[img.slot].sample_type = stringImageSampleTypeToSokolType(img.sample_type);
                try vs_images_hashmap.put(img.name, img.slot);
            }
        }

        // vs samplers
        if (shader_program.vs.samplers) |samplers| {
            for (samplers) |sample| {
                desc.vs.samplers[sample.slot].used = true;
                desc.vs.samplers[sample.slot].sampler_type = stringSampleTypeToSokolType(sample.sampler_type);
                try vs_samplers_hashmap.put(sample.name, sample.slot);
            }
        }

        // vs sampler pairs
        if (shader_program.vs.image_sampler_pairs) |pairs| {
            for (pairs) |pair| {
                desc.vs.image_sampler_pairs[pair.slot].used = true;
                desc.vs.image_sampler_pairs[pair.slot].image_slot = @intCast(vs_images_hashmap.get(pair.image_name).?);
                desc.vs.image_sampler_pairs[pair.slot].sampler_slot = @intCast(vs_samplers_hashmap.get(pair.sampler_name).?);
            }
        }

        // fragment shader defs
        desc.fs.source = shader_info.fs_source.ptr;
        desc.fs.entry = fs_entry.ptr;

        // fs uniforms
        if (shader_program.fs.uniform_blocks) |uniform_blocks| {
            for (uniform_blocks) |block| {
                desc.fs.uniform_blocks[block.slot].size = block.size;
                desc.fs.uniform_blocks[block.slot].layout = .STD140;

                for (block.uniforms, 0..) |uniform, i| {
                    const uniform_name = try terminateString(allocator, uniform.name);
                    desc.fs.uniform_blocks[block.slot].uniforms[i].name = uniform_name.ptr;
                    desc.fs.uniform_blocks[block.slot].uniforms[i].type = stringUniformTypeToSokolType(uniform.type);
                    desc.fs.uniform_blocks[block.slot].uniforms[i].array_count = uniform.array_count;
                }
            }
        }

        // fs images
        if (shader_program.fs.images) |imgs| {
            for (imgs) |img| {
                desc.fs.images[img.slot].used = true;
                desc.fs.images[img.slot].multisampled = stringBool(img.multisampled);
                desc.fs.images[img.slot].image_type = stringImageTypeToSokolType(img.type);
                desc.fs.images[img.slot].sample_type = stringImageSampleTypeToSokolType(img.sample_type);
                try fs_images_hashmap.put(img.name, img.slot);
            }
        }

        // fs samplers
        if (shader_program.fs.samplers) |samplers| {
            for (samplers) |sample| {
                desc.fs.samplers[sample.slot].used = true;
                desc.fs.samplers[sample.slot].sampler_type = stringSampleTypeToSokolType(sample.sampler_type);
                try fs_samplers_hashmap.put(sample.name, sample.slot);
            }
        }

        // fs sampler pairs
        if (shader_program.fs.image_sampler_pairs) |pairs| {
            for (pairs) |pair| {
                desc.fs.image_sampler_pairs[pair.slot].used = true;
                desc.fs.image_sampler_pairs[pair.slot].image_slot = @intCast(pair.slot);
                desc.fs.image_sampler_pairs[pair.slot].sampler_slot = @intCast(pair.slot);
            }
        }

        // vs sampler pairs
        if (shader_program.fs.image_sampler_pairs) |pairs| {
            for (pairs) |pair| {
                desc.fs.image_sampler_pairs[pair.slot].used = true;
                desc.fs.image_sampler_pairs[pair.slot].image_slot = @intCast(fs_images_hashmap.get(pair.image_name).?);
                desc.fs.image_sampler_pairs[pair.slot].sampler_slot = @intCast(fs_samplers_hashmap.get(pair.sampler_name).?);
            }
        }

        // put the shader definition that we are using into our config
        var updated_cfg = cfg;
        updated_cfg.shader_program_def = shader_program;

        return initSokolShader(updated_cfg, desc);
    }

    pub fn makeNewInstance(cfg: graphics.ShaderConfig, shader: Shader) !Shader {
        const impl = try graphics.allocator.create(ShaderImpl);

        // Make a new implementation that uses our existing loaded shader, but a fresh pipeline list
        // Mark it as being an instance, so we don't clean up our parent shader on destroy
        impl.* = .{
            .sokol_pipelines = std.ArrayList(PipelineBinding).init(graphics.allocator),
            .sokol_shader = shader.impl.sokol_shader,
            .sokol_shader_desc = shader.impl.sokol_shader_desc,
            .cfg = cfg,
            .is_instance = true,
        };

        // Copy the shader, but switch out its guts with our new one
        var newShader = shader;
        newShader.impl = impl;
        return newShader;
    }

    /// Find the shader function in the builtin that can actually make the ShaderDesc
    fn getBuiltinSokolCreateFunction(comptime builtin: anytype) ?fn (sg.Backend) sg.ShaderDesc {
        comptime {
            const decls = @typeInfo(builtin).Struct.decls;
            for (decls) |d| {
                const field = @field(builtin, d.name);
                const field_type = @typeInfo(@TypeOf(field));
                if (field_type == .Fn) {
                    const fn_info = field_type.Fn;
                    if (fn_info.return_type == sg.ShaderDesc) {
                        return field;
                    }
                }
            }
        }
        return null;
    }

    fn makePipeline(self: *ShaderImpl, layout: graphics.VertexLayout) sg.Pipeline {
        var pipe_desc: sg.PipelineDesc = .{
            .index_type = if (layout.index_size == .UINT16) .UINT16 else .UINT32,
            .shader = self.sokol_shader,
            .depth = .{
                .compare = convertCompareFunc(self.cfg.depth_compare),
                .write_enabled = self.cfg.depth_write_enabled,
            },
            .cull_mode = convertCullMode(self.cfg.cull_mode),
        };

        if (self.cfg.is_depth_pixel_format) {
            debug.log("Creating depth pixel format", .{});
            pipe_desc.depth.pixel_format = .DEPTH;
        }

        // Set the vertex attributes
        for (self.cfg.vertex_attributes, 0..) |attr, idx| {
            pipe_desc.layout.attrs[idx].format = convertVertexFormat(attr.attr_type);

            // Find which binding slot we should use by looking at our layout
            for (layout.attributes) |la| {
                if (attr.binding == la.binding) {
                    pipe_desc.layout.attrs[idx].buffer_index = la.buffer_slot;
                    break;
                }
            }
        }

        // apply blending values
        pipe_desc.colors[0].blend = convertBlendMode(self.cfg.blend_mode);

        // Ready to build our pipeline!
        const pipeline: sg.Pipeline = sg.makePipeline(pipe_desc);

        // Add this to our list of cached pipelines for this shader
        self.sokol_pipelines.append(.{ .layout = layout, .sokol_pipeline = pipeline }) catch {
            debug.log("Error caching pipeline!", .{});
        };

        return pipeline;
    }

    /// Create a shader from a Sokol Shader Description - useful for loading built-in shaders
    pub fn initSokolShader(cfg: graphics.ShaderConfig, shader_desc: sg.ShaderDesc) !Shader {
        debug.info("Creating shader: {d}", .{graphics.next_shader_handle});
        const shader = sg.makeShader(shader_desc);

        var num_fs_images: u8 = 0;
        for (0..5) |i| {
            if (shader_desc.fs.images[i].used) {
                num_fs_images += 1;
            } else {
                break;
            }
        }

        const impl = try graphics.allocator.create(ShaderImpl);
        errdefer graphics.allocator.destroy(impl);
        impl.* = .{
            .sokol_pipelines = std.ArrayList(PipelineBinding).init(graphics.allocator),
            .sokol_shader = shader,
            .sokol_shader_desc = shader_desc,
            .cfg = cfg,
        };

        defer graphics.next_shader_handle += 1;
        var built_shader = Shader{
            .impl = impl,
            .handle = graphics.next_shader_handle,
            .cfg = cfg,
            .fs_texture_slots = num_fs_images,
            .vertex_attributes = cfg.vertex_attributes,
            .shader_program_def = cfg.shader_program_def,
        };

        // Set the uniformblocks to use for this shader
        for (cfg.vs_uniformblocks, 0..) |block, i| {
            built_shader.vs_uniformblocks[i] = block;
        }
        for (cfg.fs_uniformblocks, 0..) |block, i| {
            built_shader.fs_uniformblocks[i] = block;
        }

        return built_shader;
    }

    /// Cache our common pipelines, as an optimization step
    pub fn makeCommonPipelines(self: *Shader) void {
        for (graphics.getCommonVertexLayouts()) |l| {
            _ = self.impl.makePipeline(l);
        }
    }

    pub fn apply(self: *Shader, layout: graphics.VertexLayout) bool {
        // Find the pipeline that matches our vertex layout
        var pipeline: ?sg.Pipeline = null;
        for (self.impl.sokol_pipelines.items) |p| {
            if (vertexLayoutsAreEql(p.layout, layout)) {
                pipeline = p.sokol_pipeline;
                break;
            }
        }

        if (pipeline == null) {
            pipeline = self.impl.makePipeline(layout);
        }

        if (pipeline != null) {
            sg.applyPipeline(pipeline.?);
        } else {
            debug.warning("Could not get pipeline to apply!", .{});
            return false;
        }

        // apply uniform blocks
        for (self.vs_uniformblock_data, 0..) |block, i| {
            if (block) |b|
                sg.applyUniforms(.VS, @intCast(i), sg.Range{ .ptr = b.ptr, .size = b.size });
        }

        for (self.fs_uniformblock_data, 0..) |block, i| {
            if (block) |b|
                sg.applyUniforms(.FS, @intCast(i), sg.Range{ .ptr = b.ptr, .size = b.size });
        }

        return true;
    }

    pub fn setParams(self: *Shader, params: graphics.ShaderParams) void {
        self.params = params;
    }

    pub fn destroy(self: *Shader) void {
        // TODO: Maybe only shaders, not instances, should keep all pipelines
        for (self.impl.sokol_pipelines.items) |p| {
            sg.destroyPipeline(p.sokol_pipeline);
        }

        self.impl.sokol_pipelines.deinit();

        if (!self.impl.is_instance) {
            sg.destroyShader(self.impl.sokol_shader);
        }

        graphics.allocator.destroy(self.impl);
    }
};

/// Converts our ShaderStage to a sokol shader stage
fn convertShaderStage(stage: graphics.ShaderStage) sg.ShaderStage {
    // Our enums match up, so this is easy!
    return @enumFromInt(@intFromEnum(stage));
}

/// Converts our FilterMode to a sokol sampler description
fn convertFilterModeToSamplerDesc(filter: graphics.FilterMode) sg.SamplerDesc {
    const filter_mode = if (filter == .LINEAR) sg.Filter.LINEAR else sg.Filter.NEAREST;
    return sg.SamplerDesc{
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
    switch (mode) {
        .NONE => {
            return sg.CullMode.NONE;
        },
        .BACK => {
            return sg.CullMode.FRONT;
        },
        .FRONT => {
            return sg.CullMode.BACK;
        },
    }
}

/// Converts our BlendMode enum to a Sokol BlendState struct
fn convertBlendMode(mode: graphics.BlendMode) sg.BlendState {
    switch (mode) {
        .NONE => {
            return sg.BlendState{};
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

fn convertVertexFormat(format: graphics.VertexFormat) sg.VertexFormat {
    switch (format) {
        .FLOAT2 => {
            return .FLOAT2;
        },
        .FLOAT3 => {
            return .FLOAT3;
        },
        .FLOAT4 => {
            return .FLOAT4;
        },
        .UBYTE4N => {
            return .UBYTE4N;
        },
    }
}

/// Checking if two vertex layout structs are equal
fn vertexLayoutsAreEql(a: graphics.VertexLayout, b: graphics.VertexLayout) bool {
    if (a.has_index_buffer != b.has_index_buffer) {
        return false;
    }
    if (a.index_size != b.index_size) {
        return false;
    }
    if (a.attributes.len != b.attributes.len) {
        return false;
    }
    for (0..a.attributes.len) |i| {
        const attr_a = a.attributes[i];
        const attr_b = b.attributes[i];
        if (attr_a.binding != attr_b.binding)
            return false;
        if (attr_a.buffer_slot != attr_b.buffer_slot)
            return false;
        if (attr_a.item_size != attr_b.item_size)
            return false;
    }

    return true;
}

pub fn getBackend() graphics.Backend {
    const backend = sg.queryBackend();
    return @enumFromInt(@intFromEnum(backend));
}
