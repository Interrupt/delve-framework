
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const images = @import("../images.zig");
const std = @import("std");
const math = @import("../math.zig");

const Vertex = graphics.Vertex;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

var batch_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var batch_allocator = batch_gpa.allocator();

const max_indices = 64000;
const max_vertices = max_indices;

/// Keeps track of a sub region of a texture
pub const TextureRegion = struct {
    u: f32 = 0,
    v: f32 = 0,
    u_2: f32 = 1.0,
    v_2: f32 = 1.0,

    pub fn convert(in: f32) i16 {
        return @intFromFloat(6550.0 * in);
    }

    pub fn default() TextureRegion {
        return .{.u = 0.0, .v = 0.0, .u_2 = 1.0, .v_2 = 1.0};
    }
};

const BatcherConfig = struct {
    min_vertices: usize = 128,
    min_indices: usize = 128,
    texture: ?graphics.Texture = null,
};

/// Handles drawing batches of primitive shapes, bucketed by texture / shader
pub const SpriteBatcher = struct {
    batches: std.AutoArrayHashMap(u32, Batcher) = undefined,
    transform: Mat4 = Mat4.identity(),
    draw_color: graphics.Color = graphics.Color.white(),
    config: BatcherConfig = BatcherConfig{},
    current_tex_key: u32 = 0,
    current_tex: graphics.Texture = undefined,

    pub fn init(cfg: BatcherConfig) !SpriteBatcher {
        var sprite_batcher = SpriteBatcher {
            .batches = std.AutoArrayHashMap(u32, Batcher).init(batch_allocator),
            .config = cfg
        };

        if(cfg.texture == null) {
            const debug_texture: graphics.Texture = makeDebugTexture();
            sprite_batcher.useTexture(debug_texture);
        } else {
            sprite_batcher.useTexture(cfg.texture.?);
        }

        return sprite_batcher;
    }

    /// Switch the current batch to one for the given texture
    pub fn useTexture(self: *SpriteBatcher, texture: graphics.Texture) void {
        self.current_tex_key = texture.handle;
        self.current_tex = texture;
    }

    /// Switch the current batch to one for a solid color
    pub fn useSolidColor(self: *SpriteBatcher) void {
        var solid_tex: graphics.Texture = getSolidColorTexture();
        self.current_tex_key = solid_tex.handle;
        self.current_tex = solid_tex;
    }

    /// Add a rectangle to the current batch
    pub fn addRectangle(self: *SpriteBatcher, x: f32, y: f32, width: f32, height: f32, region: TextureRegion, color: u32) void {
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addRectangle(x, y, width, height, region, color);
    }

    /// Add a triangle to the current batch
    pub fn addTriangle(self: *SpriteBatcher, x: f32, y: f32, width: f32, height: f32, region: TextureRegion, color: u32) void {
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addTriangle(x, y, width, height, region, color);
    }

    /// Gets the batcher used for the current texture
    pub fn getCurrentBatcher(self: *SpriteBatcher) ?*Batcher {
        // Return an existing batch if available
        var batcher: ?*Batcher = self.batches.getPtr(self.current_tex_key);
        if(batcher != null)
            return batcher;

        // None found, create a new batch with our config values but using a new texture
        var new_cfg = self.config;
        new_cfg.texture = self.current_tex;

        var new_batcher: Batcher = Batcher.init(new_cfg) catch {
            debug.log("Could not create a new batch for SpriteBatch!", .{});
            return null;
        };

        self.batches.put(self.current_tex_key, new_batcher) catch {
            debug.log("Could not add new batch to map for SpriteBatch!", .{});
            return null;
        };

        return self.batches.getPtr(self.current_tex_key);
    }

    /// Draws all the batches
    pub fn draw(self: *SpriteBatcher) void {
        var it = self.batches.iterator();
        while(it.next()) |batcher| {
            batcher.value_ptr.draw_color = self.draw_color;
            batcher.value_ptr.draw();
        }
    }

    /// Reset the batches for this frame
    pub fn reset(self: *SpriteBatcher) void {
        var it = self.batches.iterator();
        while(it.next()) |batcher| {
            batcher.value_ptr.reset();
        }
    }

    /// Free the batches
    pub fn deinit(self: *SpriteBatcher) void {
        var it = self.batches.iterator();
        while(it.next()) |batcher| {
            batcher.value_ptr.deinit();
        }
    }

    /// Update the transform matrix for the batches
    pub fn setTransformMatrix(self: *SpriteBatcher, matrix: Mat4) void {
        self.transform = matrix;
    }

    /// Updates all bindings for this frame with the current data
    pub fn apply(self: *SpriteBatcher) void {
        var it = self.batches.iterator();
        while(it.next()) |batcher| {
            batcher.value_ptr.apply();
        }
    }
};

/// Handles drawing a batch of primitive shapes all with the same texture / shader
pub const Batcher = struct {
    vertex_buffer: []Vertex,
    index_buffer: []u16,
    vertex_pos: usize,
    index_pos: usize,
    bindings: graphics.Bindings,
    shader: graphics.Shader,
    draw_color: graphics.Color = graphics.Color.white(),
    transform: Mat4 = Mat4.identity(),

    /// Setup and return a new Batcher
    pub fn init(cfg: BatcherConfig) !Batcher {
        var batcher: Batcher = Batcher {
            .vertex_pos = 0,
            .index_pos = 0,
            .vertex_buffer = try batch_allocator.alloc(Vertex, cfg.min_vertices),
            .index_buffer = try batch_allocator.alloc(u16, cfg.min_indices),
            .bindings = graphics.Bindings.init(.{.updatable = true, .index_len = cfg.min_indices, .vert_len = cfg.min_vertices}),
            .shader = graphics.Shader.init(.{ }),
        };

        if(cfg.texture == null) {
            var solid_tex = getSolidColorTexture();
            batcher.setTexture(solid_tex);
        } else {
            batcher.setTexture(cfg.texture.?);
        }

        return batcher;
    }

    pub fn deinit(self: *Batcher) void {
        self.bindings.destroy();
        batch_allocator.free(self.vertex_buffer);
        batch_allocator.free(self.index_buffer);
    }

    /// Sets the texture from an Image that will be used when drawing the batch
    pub fn setTextureFromImage(self: *Batcher, image: *images.Image) void {
        const texture = graphics.Texture.init(image);
        self.bindings.setTexture(texture);
        self.draw_calls[0].texture = texture;
    }

    /// Sets the texture that will be used when drawing the batch
    pub fn setTexture(self: *Batcher, texture: graphics.Texture) void {
        self.bindings.setTexture(texture);
    }

    pub fn setTransformMatrix(self: *Batcher, matrix: Mat4) void {
        self.transform = matrix;
    }

    pub fn addQuad(self: *Batcher, v0: Vec2, v1: Vec2, v2: Vec2, v3: Vec2, region: TextureRegion, color: u32) void {
        self.growBuffersToFit(self.vertex_pos + 4, self.index_pos + 6) catch {
            return;
        };

        const u = TextureRegion.convert(region.u);
        const v = TextureRegion.convert(region.v);
        const u_2 = TextureRegion.convert(region.u_2);
        const v_2 = TextureRegion.convert(region.v_2);

        const verts = &[_]Vertex{
            .{ .x = v0.x, .y = v0.y, .z = 0, .color = color, .u = u, .v = v },
            .{ .x = v1.x, .y = v1.y, .z = 0, .color = color, .u = u_2, .v = v },
            .{ .x = v2.x, .y = v2.y, .z = 0, .color = color, .u = u_2, .v = v_2},
            .{ .x = v3.x, .y = v3.y, .z = 0, .color = color, .u = u, .v = v_2},
        };

        const indices = &[_]u16{ 0, 1, 2, 0, 2, 3 };

        for(verts, 0..) |vert, i| {
            self.vertex_buffer[self.vertex_pos + i] = Vertex.mulMat4(vert, self.transform);
        }

        const v_pos = @as(u16, @intCast(self.vertex_pos));
        for(indices, 0..) |idx, i| {
            self.index_buffer[self.index_pos + i] = idx + v_pos;
        }

        self.vertex_pos += verts.len;
        self.index_pos += indices.len;
    }

    /// Add a rectangle to the batch
    pub fn addRectangle(self: *Batcher, x: f32, y: f32, width: f32, height: f32, region: TextureRegion, color: u32) void {
        const v0 = Vec2 { .x = x, .y = y + height };
        const v1 = Vec2 { .x = x + width, .y = y + height };
        const v2 = Vec2 { .x = x + width, .y = y };
        const v3 = Vec2 { .x = x, .y = y };

        self.addQuad(v0, v1, v2, v3, region, color);
    }

    /// Add a triangle to the batch
    pub fn addTriangle(self: *Batcher, x: f32, y: f32, width: f32, height: f32, region: TextureRegion, color: u32) void {
        self.growBuffersToFit(self.vertex_pos + 3, self.index_pos + 3) catch {
            return;
        };

        const u = TextureRegion.convert(region.u);
        const v = TextureRegion.convert(region.v);
        const u_2 = TextureRegion.convert(region.u_2);
        const v_2 = TextureRegion.convert(region.v_2);
        const u_mid = @divTrunc((u_2 - u), 2);

        const verts = &[_]Vertex{
            .{ .x = x + width / 2.0, .y = y + height, .z = 0, .color = color, .u = u_mid, .v = v},
            .{ .x = x, .y = y, .z = 0, .color = color, .u = u, .v = v_2},
            .{ .x = x + width, .y = y, .z = 0, .color = color, .u = u_2, .v = v_2},
        };

        const indices = &[_]u16{ 0, 1, 2 };

        for(verts, 0..) |vert, i| {
            self.vertex_buffer[self.vertex_pos + i] = Vertex.mulMat4(vert, self.transform);
        }

        const v_pos = @as(u16, @intCast(self.vertex_pos));
        for(indices, 0..) |idx, i| {
            self.index_buffer[self.index_pos + i] = idx + v_pos;
        }

        self.vertex_pos += verts.len;
        self.index_pos += indices.len;
    }

    /// Updates our bindings for this frame with the current data
    pub fn apply(self: *Batcher) void {
        self.bindings.update(self.vertex_buffer, self.index_buffer, self.vertex_pos, self.index_pos);
    }

    /// Resets the batch to empty, without clearing memory
    pub fn reset(self: *Batcher) void {
        self.vertex_pos = 0;
        self.index_pos = 0;
    }

    /// Submit a draw call to draw all shapes for this batch
    pub fn draw(self: *Batcher) void {
        if(self.index_pos == 0)
            return;

        graphics.setDrawColor(self.draw_color);
        graphics.draw(&self.bindings, &self.shader);
    }

    /// Expand the buffers for this batch if needed to fit the new size
    fn growBuffersToFit(self: *Batcher, needed_vertices: usize, needed_indices: usize) !void {
        if(needed_vertices > max_vertices or needed_indices > max_indices) {
            debug.log("Can't grow buffer to fit!: verts:{d} idxs:{d}", .{needed_vertices, needed_indices});
            return;
        }

        var needs_resize = false;

        if(self.vertex_buffer.len < needed_vertices) {
            // debug.log("Growing vertex buffer to {d}", .{self.vertex_buffer.len * 2});
            self.vertex_buffer = batch_allocator.realloc(self.vertex_buffer, self.vertex_buffer.len * 2) catch {
                debug.log("Could not allocate needed vertices! Needed {d}", .{needed_vertices});
                return;
            };
            needs_resize = true;
        }
        if(self.index_buffer.len < needed_indices) {
            // debug.log("Growing index buffer to {d}", .{self.index_buffer.len * 2});
            self.index_buffer = batch_allocator.realloc(self.index_buffer, self.index_buffer.len * 2) catch {
                debug.log("Could not allocate needed indices! Needed {d}", .{needed_indices});
                return;
            };
            needs_resize = true;
        }

        if(!needs_resize)
            return;

        // debug.log("Resizing buffer to {d}x{d}", .{self.vertex_buffer.len, self.index_buffer.len});
        self.bindings.resize(self.vertex_buffer.len, self.index_buffer.len);
    }
};

/// Returns a checkerboard texture for debugging
fn makeDebugTexture() graphics.Texture {
    const img = &[4 * 4]u32{
        0xFF999999, 0xFF555555, 0xFF999999, 0xFF555555,
        0xFF555555, 0xFF999999, 0xFF555555, 0xFF999999,
        0xFF999999, 0xFF555555, 0xFF999999, 0xFF555555,
        0xFF555555, 0xFF999999, 0xFF555555, 0xFF999999,
    };
    return graphics.Texture.initFromBytes(4, 4, img);
}

/// Returns a solid white texture
fn makeSolidColorTexture() graphics.Texture {
    const img = &[2 * 2]u32{
        0xFFFFFFFF, 0xFFFFFFFF,
        0xFFFFFFFF, 0xFFFFFFFF,
    };
    return graphics.Texture.initFromBytes(2, 2, img);
}

var solid_texture: ?graphics.Texture = null;

/// Gets or creates the solid color texture
fn getSolidColorTexture() graphics.Texture {
    if(solid_texture == null)
        solid_texture = makeSolidColorTexture();

    return solid_texture.?;
}
