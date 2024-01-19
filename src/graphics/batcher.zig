
const std = @import("std");
const debug = @import("../debug.zig");
const colors = @import("../colors.zig");
const graphics = @import("../platform/graphics.zig");
const images = @import("../images.zig");
const math = @import("../math.zig");

// needed to hash materials into keys
const autoHash = std.hash.autoHash;
const Wyhash = std.hash.Wyhash;

const Vertex = graphics.Vertex;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Color = colors.Color;

var batch_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var batch_allocator = batch_gpa.allocator();

const max_indices = 64000;
const max_vertices = max_indices;

const VSParams = graphics.VSDefaultUniforms;
const FSParams = graphics.FSDefaultUniforms;

/// Keeps track of a sub region of a texture
pub const TextureRegion = struct {
    u: f32 = 0,
    v: f32 = 0,
    u_2: f32 = 1.0,
    v_2: f32 = 1.0,

    pub fn default() TextureRegion {
        return .{.u = 0.0, .v = 0.0, .u_2 = 1.0, .v_2 = 1.0};
    }

    pub fn flipY(self: TextureRegion) TextureRegion {
        return .{ .u = self.u, .v = self.v_2, .u_2 = self.u_2, .v_2 = self.v };
    }
};

const BatcherConfig = struct {
    min_vertices: usize = 128,
    min_indices: usize = 128,
    texture: ?graphics.Texture = null,
    shader: ?graphics.Shader = null,
    material: ?*graphics.Material = null,
    flip_tex_y: bool = false,
};

/// Handles drawing batches of primitive shapes, bucketed by texture / shader
pub const SpriteBatcher = struct {
    batches: std.AutoArrayHashMap(u64, Batcher) = undefined,
    transform: Mat4 = Mat4.identity(),
    draw_color: colors.Color = colors.white,
    config: BatcherConfig = BatcherConfig{},
    current_batch_key: u64 = 0,
    current_tex: graphics.Texture = undefined,
    current_shader: graphics.Shader = undefined,
    current_material: ?*graphics.Material = null,

    pub fn init(cfg: BatcherConfig) !SpriteBatcher {
        var sprite_batcher = SpriteBatcher {
            .batches = std.AutoArrayHashMap(u64, Batcher).init(batch_allocator),
            .config = cfg
        };

        // set initial texture and shader
        const tex = if(cfg.texture != null) cfg.texture.? else graphics.createDebugTexture();
        sprite_batcher.current_tex = tex;

        const shader = if(cfg.shader != null) cfg.shader.? else graphics.Shader.initDefault(.{ });
        sprite_batcher.useShader(shader);

        return sprite_batcher;
    }

    /// Switch the current batch to one for the given texture
    pub fn useTexture(self: *SpriteBatcher, texture: graphics.Texture) void {
        self.current_batch_key = makeSpriteBatchKey(texture, self.current_shader);
        self.current_tex = texture;
        self.current_material = null;
    }

    /// Switch the current batch to one for the given shader
    pub fn useShader(self: *SpriteBatcher, shader: graphics.Shader) void {
        self.current_batch_key = makeSpriteBatchKey(self.current_tex, shader);
        self.current_shader = shader;
        self.current_material = null;
    }

    /// Switch the current batch to one for a solid color
    pub fn useSolidColor(self: *SpriteBatcher) void {
        var solid_tex: graphics.Texture = graphics.tex_white;
        self.current_batch_key = solid_tex.handle;
        self.current_tex = solid_tex;
        self.current_material = null;
    }

    /// Switch the current batch to one for the given material
    pub fn useMaterial(self: *SpriteBatcher, material: *graphics.Material) void {
        self.current_batch_key = makeSpriteBatchKeyFromMaterial(material);
        self.current_material = material;
    }

    /// Add a rectangle to the current batch
    pub fn addRectangle(self: *SpriteBatcher, pos: Vec2, size: Vec2, region: TextureRegion, color: Color) void {
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addRectangle(pos, size, region, color);
    }

    /// Add a rectangle of lines to the current batch
    pub fn addLineRectangle(self: *SpriteBatcher, pos: Vec2, size: Vec2, line_width: f32, region: TextureRegion, color: Color) void {
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addLineRectangle(pos, size, line_width, region, color);
    }

    /// Add an equilateral triangle to the current batch
    pub fn addTriangle(self: *SpriteBatcher, pos: Vec2, size: Vec2, region: TextureRegion, color: Color) void {
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addTriangle(pos, size, region, color);
    }

    /// Adds a freeform triangle to the current batch
    pub fn addTriangleFromVecs(self: *SpriteBatcher, v0: Vec2, v1: Vec2, v2: Vec2, uv0: Vec2, uv1: Vec2, uv2: Vec2, color: Color) void {
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addTriangleFromVecs(v0, v1, v2, uv0, uv1, uv2, color);
    }

    /// Adds a textured line to the current batch
    pub fn addLine(self: *SpriteBatcher, from: Vec2, to: Vec2, width: f32, region: TextureRegion, color: Color) void {
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addLine(from, to, width, region, color);
    }

    /// Gets the batcher used for the current texture
    pub fn getCurrentBatcher(self: *SpriteBatcher) ?*Batcher {
        // Return an existing batch if available
        var batcher: ?*Batcher = self.batches.getPtr(self.current_batch_key);
        if(batcher != null)
            return batcher;

        // None found, create a new batch!
        var new_cfg = self.config;
        if(self.current_material == null) {
            new_cfg.texture = self.current_tex;
            new_cfg.shader = self.current_shader;
        } else {
            new_cfg.material = self.current_material;
        }

        var new_batcher: Batcher = Batcher.init(new_cfg) catch {
            debug.log("Could not create a new batch for SpriteBatch!", .{});
            return null;
        };

        self.batches.put(self.current_batch_key, new_batcher) catch {
            debug.log("Could not add new batch to map for SpriteBatch!", .{});
            return null;
        };

        return self.batches.getPtr(self.current_batch_key);
    }

    /// Draws all the batches
    pub fn draw(self: *SpriteBatcher, proj_view_matrix: Mat4, model_matrix: Mat4) void {
        var it = self.batches.iterator();
        while(it.next()) |batcher| {
            batcher.value_ptr.draw(proj_view_matrix, model_matrix);
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

fn makeSpriteBatchKey(tex: graphics.Texture, shader: graphics.Shader) u64 {
    return tex.handle + (shader.handle * 1000000);
}

fn makeSpriteBatchKeyFromMaterial(material: *const graphics.Material) u64 {
    // Hash the material, just like an auto map would.
    var hasher = Wyhash.init(0);
    autoHash(&hasher, material);
    return hasher.final();
}

/// Handles drawing a batch of primitive shapes all with the same texture / shader
pub const Batcher = struct {
    vertex_buffer: []Vertex,
    index_buffer: []u32,
    vertex_pos: usize,
    index_pos: usize,
    bindings: graphics.Bindings,
    shader: graphics.Shader,
    material: ?*graphics.Material = null,
    transform: Mat4 = Mat4.identity(),
    flip_tex_y: bool = false,

    /// Setup and return a new Batcher
    pub fn init(cfg: BatcherConfig) !Batcher {
        var batcher: Batcher = Batcher {
            .vertex_pos = 0,
            .index_pos = 0,
            .vertex_buffer = try batch_allocator.alloc(Vertex, cfg.min_vertices),
            .index_buffer = try batch_allocator.alloc(u32, cfg.min_indices),
            .bindings = graphics.Bindings.init(.{.updatable = true, .index_len = cfg.min_indices, .vert_len = cfg.min_vertices}),
            .shader = if(cfg.shader != null) cfg.shader.? else graphics.Shader.initDefault(.{ }),
            .material = if(cfg.material != null) cfg.material.? else null,
            .flip_tex_y = cfg.flip_tex_y,
        };

        if(cfg.texture == null) {
            batcher.setTexture(graphics.tex_white);
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
    }

    /// Sets the texture that will be used when drawing the batch
    pub fn setTexture(self: *Batcher, texture: graphics.Texture) void {
        self.bindings.setTexture(texture);
    }

    /// Sets the transform matrix that will be used to transform shapes when adding
    pub fn setTransformMatrix(self: *Batcher, matrix: Mat4) void {
        self.transform = matrix;
    }

    /// Add a four sided quad shape to the batch
    pub fn addQuad(self: *Batcher, v0: Vec2, v1: Vec2, v2: Vec2, v3: Vec2, tex_region: TextureRegion, color: Color) void {
        self.growBuffersToFit(self.vertex_pos + 4, self.index_pos + 6) catch {
            return;
        };

        const region = if(self.flip_tex_y) tex_region.flipY() else tex_region;

        const u = region.u;
        const v = region.v;
        const u_2 = region.u_2;
        const v_2 = region.v_2;
        const color_i = color.toInt();

        const verts = &[_]Vertex{
            .{ .x = v0.x, .y = v0.y, .z = 0, .color = color_i, .u = u, .v = v },
            .{ .x = v1.x, .y = v1.y, .z = 0, .color = color_i, .u = u_2, .v = v },
            .{ .x = v2.x, .y = v2.y, .z = 0, .color = color_i, .u = u_2, .v = v_2},
            .{ .x = v3.x, .y = v3.y, .z = 0, .color = color_i, .u = u, .v = v_2},
        };

        const indices = &[_]u32{ 0, 1, 2, 0, 2, 3 };

        for(verts, 0..) |vert, i| {
            self.vertex_buffer[self.vertex_pos + i] = Vertex.mulMat4(vert, self.transform);
        }

        const v_pos = @as(u32, @intCast(self.vertex_pos));
        for(indices, 0..) |idx, i| {
            self.index_buffer[self.index_pos + i] = idx + v_pos;
        }

        self.vertex_pos += verts.len;
        self.index_pos += indices.len;
    }

    /// Add a rectangle to the batch
    pub fn addRectangle(self: *Batcher, pos: Vec2, size: Vec2, region: TextureRegion, color: Color) void {
        const v0 = pos.add(Vec2{.x = 0, .y = size.y});
        const v1 = pos.add(Vec2{.x = size.x, .y = size.y});
        const v2 = pos.add(Vec2{.x = size.x, .y = 0});
        const v3 = pos;

        self.addQuad(v0, v1, v2, v3, region, color);
    }

    /// Add a line to the batch
    pub fn addLine(self: *Batcher, from: Vec2, to: Vec2, width: f32, region: TextureRegion, color: Color) void {
        const normal = to.sub(from).norm();
        const right = Vec2.scale(&Vec2{.x=-normal.y, .y=normal.x}, width * 0.5);

        const v0 = from.add(right);
        const v1 = to.add(right);
        const v2 = to.sub(right);
        const v3 = from.sub(right);

        // A line with a width is really just a quad
        self.addQuad(v0, v1, v2, v3, region, color);
    }

    /// Add a rectangle made of lines to the batch
    pub fn addLineRectangle(self: *Batcher, pos: Vec2, size: Vec2, line_width: f32, region: TextureRegion, color: Color) void {
        const w: f32 = line_width * 0.5;

        // top and bottom
        self.addLine(Vec2.new(pos.x - w, pos.y), Vec2.new(pos.x + size.x + w, pos.y), line_width, region, color);
        self.addLine(Vec2.new(pos.x - w, pos.y + size.y), Vec2.new(pos.x + size.x + w, pos.y + size.y), line_width, region, color);

        // sides
        self.addLine(Vec2.new(pos.x, pos.y), Vec2.new(pos.x, pos.y + size.y), line_width, region, color);
        self.addLine(Vec2.new(pos.x + size.x, pos.y), Vec2.new(pos.x + size.x, pos.y + size.y), line_width, region, color);
    }

    /// Adds an equilateral triangle to the batch
    pub fn addTriangle(self: *Batcher, pos: Vec2, size: Vec2, tex_region: TextureRegion, color: Color) void {
        const region = if(self.flip_tex_y) tex_region.flipY() else tex_region;

        const v0: Vec2 = Vec2{.x = pos.x + size.x / 2.0, .y = pos.y + size.y};
        const v1: Vec2 = pos;
        const v2: Vec2 = Vec2{.x = pos.x + size.x, .y = pos.y };

        const u_mid = (region.u + region.u_2) / 2.0;

        const uv0: Vec2 = Vec2.new(u_mid, region.v);
        const uv1: Vec2 = Vec2.new(region.u, region.v_2);
        const uv2: Vec2 = Vec2.new(region.u_2, region.v_2);

        self.addTriangleFromVecs(v0, v1, v2, uv0, uv1, uv2, color);
    }

    /// Add a freeform triangle to the batch
    pub fn addTriangleFromVecs(self: *Batcher, v0: Vec2, v1: Vec2, v2: Vec2, uv0: Vec2, uv1: Vec2, uv2: Vec2, color: Color) void {
        self.growBuffersToFit(self.vertex_pos + 3, self.index_pos + 3) catch {
            return;
        };

        const color_i = color.toInt();

        const verts = &[_]Vertex{
            .{ .x = v0.x, .y = v0.y, .z = 0, .color = color_i, .u = uv0.x, .v = uv0.y },
            .{ .x = v1.x, .y = v1.y, .z = 0, .color = color_i, .u = uv1.x, .v = uv1.y },
            .{ .x = v2.x, .y = v2.y, .z = 0, .color = color_i, .u = uv2.x, .v = uv2.y },
        };

        const indices = &[_]u32{ 0, 1, 2 };

        for(verts, 0..) |vert, i| {
            self.vertex_buffer[self.vertex_pos + i] = Vertex.mulMat4(vert, self.transform);
        }

        const v_pos = @as(u32, @intCast(self.vertex_pos));
        for(indices, 0..) |idx, i| {
            self.index_buffer[self.index_pos + i] = idx + v_pos;
        }

        self.vertex_pos += verts.len;
        self.index_pos += indices.len;
    }

    /// Adds a circle to the batch
    pub fn addCircle(self: *Batcher, center: Vec2, radius: f32, steps: i32, region: TextureRegion, color: Color) void {
        var last = angleToVector(0, radius);

        const tau = std.math.pi * 2.0;

        _ = region;

        const uv0 = Vec2.zero();
        const uv1 = Vec2.zero();
        const uv2 = Vec2.zero();

        for(0 .. @intCast(steps+1)) |i| {
            const if32: f32 = @floatFromInt(i);
            const next = angleToVector(if32 / @as(f32, @floatFromInt(steps)) * tau, radius);

            self.addTriangleFromVecs(center.add(last), center.add(next), center, uv0, uv1, uv2, color);
            last = next;
        }
    }

    /// Adds an outlined circle to the batch
    pub fn addLineCircle(self: *Batcher, center: Vec2, radius: f32, steps: i32, line_width: f32, region: TextureRegion, color: Color) void {
        var last = angleToVector(0, radius);

        for(0 .. @intCast(steps+1)) |i| {
            const if32: f32 = @floatFromInt(i);
            const next = angleToVector(if32 / @as(f32, @floatFromInt(steps)) * std.math.tau, radius);

            const start = center.add(last);
            const end = center.add(next);

            self.addLine(start, end, line_width, region, color);
            last = next;
        }
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
    pub fn draw(self: *Batcher, proj_view_matrix: Mat4, model_matrix: Mat4) void {
        if(self.material == null) {
            self.drawWithoutMaterial(proj_view_matrix, model_matrix);
        } else {
            self.drawWithMaterial(proj_view_matrix, model_matrix);
        }
    }

    /// Submit a draw call to draw all shapes for this batch
    pub fn drawWithoutMaterial(self: *Batcher, proj_view_matrix: Mat4, model_matrix: Mat4) void {
        if(self.index_pos == 0)
            return;

        // Make our default uniform blocks
        const vs_params = VSParams {
            .projViewMatrix = proj_view_matrix,
            .modelMatrix = model_matrix,
            .in_color = .{ 1.0, 1.0, 1.0, 1.0 },
        };

        const fs_params = FSParams {
            .in_color_override = .{0.0, 0.0, 0.0, 0.0},
        };

        // set our default vs/fs shader uniforms to the 0 slots
        self.shader.applyUniformBlock(.FS, 0, graphics.asAnything(&fs_params));
        self.shader.applyUniformBlock(.VS, 0, graphics.asAnything(&vs_params));

        graphics.draw(&self.bindings, &self.shader);
    }

    /// Submit a draw call to draw all shapes for this batch
    pub fn drawWithMaterial(self: *Batcher, proj_view_matrix: Mat4, model_matrix: Mat4) void {
        if(self.index_pos == 0)
            return;

        if(self.material == null)
            return;

        // set positions
        self.material.?.params.proj_view_matrix = proj_view_matrix;
        self.material.?.params.model_matrix = model_matrix;

        graphics.drawWithMaterial(&self.bindings, self.material.?);
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

fn angleToVector(angle: f32, length: f32) Vec2 {
    return Vec2{ .x = std.math.cos(angle) * length, .y = std.math.sin(angle) * length };
}
