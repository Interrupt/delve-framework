
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
        var solid_tex: graphics.Texture = graphics.tex_white;
        self.current_tex_key = solid_tex.handle;
        self.current_tex = solid_tex;
    }

    /// Add a rectangle to the current batch
    pub fn addRectangle(self: *SpriteBatcher, texture: graphics.Texture, pos: Vec2, size: Vec2, region: TextureRegion, color: u32) void {
        self.useTexture(texture);
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addRectangle(pos, size, region, color);
    }

    /// Add a rectangle of lines to the current batch
    pub fn addLineRectangle(self: *SpriteBatcher, texture: graphics.Texture, pos: Vec2, size: Vec2, line_width: f32, region: TextureRegion, color: u32) void {
        self.useTexture(texture);
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addLineRectangle(pos, size, line_width, region, color);
    }

    /// Add an equilateral triangle to the current batch
    pub fn addTriangle(self: *SpriteBatcher, texture: graphics.Texture, pos: Vec2, size: Vec2, region: TextureRegion, color: u32) void {
        self.useTexture(texture);
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addTriangle(pos, size, region, color);
    }

    /// Adds a freeform triangle to the current batch
    pub fn addTriangleFromVecs(self: *SpriteBatcher, texture: graphics.Texture, v0: Vec2, v1: Vec2, v2: Vec2, uv0: Vec2, uv1: Vec2, uv2: Vec2, color: u32) void {
        self.useTexture(texture);
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addTriangleFromVecs(v0, v1, v2, uv0, uv1, uv2, color);
    }

    /// Adds a textured line to the current batch
    pub fn addLine(self: *SpriteBatcher, texture: graphics.Texture, from: Vec2, to: Vec2, width: f32, region: TextureRegion, color: u32) void {
        self.useTexture(texture);
        var batcher: ?*Batcher = self.getCurrentBatcher();
        if(batcher == null)
            return;

        batcher.?.transform = self.transform;
        batcher.?.addLine(from, to, width, region, color);
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
    pub fn addRectangle(self: *Batcher, pos: Vec2, size: Vec2, region: TextureRegion, color: u32) void {
        const v0 = Vec2.add(pos, Vec2{.x = 0, .y = size.y});
        const v1 = Vec2.add(pos, Vec2{.x = size.x, .y = size.y});
        const v2 = Vec2.add(pos, Vec2{.x = size.x, .y = 0});
        const v3 = pos;

        self.addQuad(v0, v1, v2, v3, region, color);
    }

    /// Add a line to the batch
    pub fn addLine(self: *Batcher, from: Vec2, to: Vec2, width: f32, region: TextureRegion, color: u32) void {
        const normal = Vec2.norm(Vec2.sub(to, from));
        const right = Vec2.mul(Vec2{.x=-normal.y, .y=normal.x}, width * 0.5);

        const v0 = Vec2.add(from, right);
        const v1 = Vec2.add(to, right);
        const v2 = Vec2.sub(to, right);
        const v3 = Vec2.sub(from, right);

        // A line with a width is really just a quad
        self.addQuad(v0, v1, v2, v3, region, color);
    }

    /// Add a rectangle made of lines to the batch
    pub fn addLineRectangle(self: *Batcher, pos: Vec2, size: Vec2, line_width: f32, region: TextureRegion, color: u32) void {
        const w: f32 = line_width * 0.5;

        // top and bottom
        self.addLine(math.vec2(pos.x - w, pos.y), math.vec2(pos.x + size.x + w, pos.y), line_width, region, color);
        self.addLine(math.vec2(pos.x - w, pos.y + size.y), math.vec2(pos.x + size.x + w, pos.y + size.y), line_width, region, color);

        // sides
        self.addLine(math.vec2(pos.x, pos.y), math.vec2(pos.x, pos.y + size.y), line_width, region, color);
        self.addLine(math.vec2(pos.x + size.x, pos.y), math.vec2(pos.x + size.x, pos.y + size.y), line_width, region, color);
    }

    /// Adds an equilateral triangle to the batch
    pub fn addTriangle(self: *Batcher, pos: Vec2, size: Vec2, region: TextureRegion, color: u32) void {
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
    pub fn addTriangleFromVecs(self: *Batcher, v0: Vec2, v1: Vec2, v2: Vec2, uv0: Vec2, uv1: Vec2, uv2: Vec2, color: u32) void {
        self.growBuffersToFit(self.vertex_pos + 3, self.index_pos + 3) catch {
            return;
        };

        const verts = &[_]Vertex{
            .{ .x = v0.x, .y = v0.y, .z = 0, .color = color, .u = floatToIntUV(uv0.x), .v = floatToIntUV(uv0.y) },
            .{ .x = v1.x, .y = v1.y, .z = 0, .color = color, .u = floatToIntUV(uv1.x), .v = floatToIntUV(uv1.y) },
            .{ .x = v2.x, .y = v2.y, .z = 0, .color = color, .u = floatToIntUV(uv2.x), .v = floatToIntUV(uv2.y) },
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

    /// Adds a circle to the batch
    pub fn addCircle(self: *Batcher, center: Vec2, radius: f32, steps: i32, region: TextureRegion, color: u32) void {
        var last = angleToVector(0, radius);

        const tau = std.math.pi * 2.0;

        _ = region;

        const uv0 = Vec2.zero();
        const uv1 = Vec2.zero();
        const uv2 = Vec2.zero();

        for(0 .. @intCast(steps+1)) |i| {
            const if32: f32 = @floatFromInt(i);
            const next = angleToVector(if32 / @as(f32, @floatFromInt(steps)) * tau, radius);
            self.addTriangleFromVecs(Vec2.add(center, last), Vec2.add(center, next), center, uv0, uv1, uv2, color);
            last = next;
        }
    }

    /// Adds a line circle to the batch
    pub fn addLineCircle(self: *Batcher, center: Vec2, radius: f32, steps: i32, line_width: f32, region: TextureRegion, color: u32) void {
        var last = angleToVector(0, radius);

        const tau = std.math.pi * 2.0;

        for(0 .. @intCast(steps+1)) |i| {
            const if32: f32 = @floatFromInt(i);
            const next = angleToVector(if32 / @as(f32, @floatFromInt(steps)) * tau, radius);

            const start = Vec2.add(center, last);
            const end = Vec2.add(center, next);

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

fn floatToIntUV(in: f32) i16 {
    return @intFromFloat(6550.0 * in);
}

fn angleToVector(angle: f32, length: f32) Vec2 {
    return Vec2{ .x = std.math.cos(angle) * length, .y = std.math.sin(angle) * length };
}
