
const std = @import("std");
const debug = @import("../../../debug.zig");
const graphics = @import("../../graphics.zig");
const images = @import("../../../images.zig");

const sokol = @import("sokol");
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
                .size = cfg.index_len * @sizeOf(u16),
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
            .size = index_len * @sizeOf(u16),
        });
    }

    pub fn drawSubset(bindings: *Bindings, start: u32, end: u32, shader: *Shader) void {
        if(bindings.impl.sokol_bindings == null or shader.sokol_pipeline == null)
            return;

        shader.apply();

        sg.applyBindings(bindings.impl.sokol_bindings.?);
        sg.draw(start, end, 1);
    }
};

fn convertFilterModeToSamplerDesc(filter: graphics.FilterMode) sg.SamplerDesc {
    const filter_mode = if (filter == .LINEAR) sg.Filter.LINEAR else sg.Filter.NEAREST;
    return sg.SamplerDesc {
        .min_filter = filter_mode,
        .mag_filter = filter_mode,
        .mipmap_filter = filter_mode,
    };
}
