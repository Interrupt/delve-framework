
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const images = @import("../images.zig");
const std = @import("std");
const math = @import("../math.zig");

const Vertex = graphics.Vertex;
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

var batch_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var batch_allocator = batch_gpa.allocator();

const max_indices = 64000;
const max_vertices = max_indices;

const min_indices = 32;
const min_vertices = min_indices;

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

/// Info on a single drawcall in the buffer
const DrawCall = struct {
    start: usize,
    end: usize,
    texture: *graphics.Texture,
    shader: *graphics.Shader,
};

/// Handles drawing a batch of primitive shapes
pub const Batcher = struct {
    vertex_buffer: []Vertex,
    index_buffer: []u16,
    vertex_pos: usize,
    index_pos: usize,
    num_draw_calls: usize,
    bindings: graphics.Bindings,
    shader: graphics.Shader,
    draw_color: graphics.Color = graphics.Color.white(),
    draw_calls: []DrawCall = undefined,
    transform: Mat4 = Mat4.identity(),

    /// Setup and return a new Batcher
    pub fn init() !Batcher {
        var batcher: Batcher = Batcher {
            .vertex_pos = 0,
            .index_pos = 0,
            .num_draw_calls = 0,
            .vertex_buffer = try batch_allocator.alloc(Vertex, min_vertices),
            .index_buffer = try batch_allocator.alloc(u16, min_indices),
            .bindings = graphics.Bindings.init(.{.updatable = true, .index_len = 64000, .vert_len = 64000}),
            .shader = graphics.Shader.init(.{ }),
            .draw_calls = try batch_allocator.alloc(DrawCall, 64),
        };

        // create a small debug checker-board texture
        const img = &[4 * 4]u32{
            0xFF999999, 0xFF555555, 0xFF999999, 0xFF555555,
            0xFF555555, 0xFF999999, 0xFF555555, 0xFF999999,
            0xFF999999, 0xFF555555, 0xFF999999, 0xFF555555,
            0xFF555555, 0xFF999999, 0xFF555555, 0xFF999999,
        };
        const texture = graphics.Texture.initFromBytes(4, 4, img);
        batcher.setTexture(texture);

        return batcher;
    }

    pub fn deinit() void {
        // todo: dealloc here
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

    pub fn setTransformMatrix(self: *Batcher, matrix: Mat4) void {
        self.transform = matrix;
    }

    /// Add a rectangle to the batch
    pub fn addRectangle(self: *Batcher, x: f32, y: f32, z: f32, width: f32, height: f32, region: TextureRegion, color: u32) void {
        self.growBuffersToFit(self.vertex_pos + 4, self.index_pos + 6) catch {
            return;
        };

        const u = TextureRegion.convert(region.u);
        const v = TextureRegion.convert(region.v);
        const u_2 = TextureRegion.convert(region.u_2);
        const v_2 = TextureRegion.convert(region.v_2);

        const verts = &[_]Vertex{
            Vertex.mulMat4(.{ .x = x, .y = y + height, .z = z, .color = color, .u = u, .v = v }, self.transform),
            Vertex.mulMat4(.{ .x = x + width, .y = y + height, .z = z, .color = color, .u = u_2, .v = v }, self.transform),
            Vertex.mulMat4(.{ .x = x + width, .y = y, .z = z, .color = color, .u = u_2, .v = v_2}, self.transform),
            Vertex.mulMat4(.{ .x = x, .y = y, .z = z, .color = color, .u = u, .v = v_2}, self.transform),
        };

        const indices = &[_]u16{ 0, 1, 2, 0, 2, 3 };

        for(verts, 0..) |vert, i| {
            self.vertex_buffer[self.vertex_pos + i] = vert;
        }

        const v_pos = @as(u16, @intCast(self.vertex_pos));
        for(indices, 0..) |idx, i| {
            self.index_buffer[self.index_pos + i] = idx + v_pos;
        }

        self.vertex_pos += verts.len;
        self.index_pos += indices.len;
    }

    /// Add a triangle to the batch
    pub fn addTriangle(self: *Batcher, x: f32, y: f32, z: f32, width: f32, height: f32, region: TextureRegion, color: u32) void {
        self.growBuffersToFit(self.vertex_pos + 3, self.index_pos + 3) catch {
            return;
        };

        const u = TextureRegion.convert(region.u);
        const v = TextureRegion.convert(region.v);
        const u_2 = TextureRegion.convert(region.u_2);
        const v_2 = TextureRegion.convert(region.v_2);
        const u_mid = @divTrunc((u_2 - u), 2);

        const verts = &[_]Vertex{
            .{ .x = x + width / 2.0, .y = y + height, .z = z, .color = color, .u = u_mid, .v = v},
            .{ .x = x, .y = y, .z = z, .color = color, .u = u, .v = v_2},
            .{ .x = x + width, .y = y, .z = z, .color = color, .u = u_2, .v = v_2},
        };

        const indices = &[_]u16{ 0, 1, 2 };

        for(verts, 0..) |vert, i| {
            self.vertex_buffer[self.vertex_pos + i] = vert;
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
        self.num_draw_calls = 0;
    }

    /// Submit a draw call for this batch
    pub fn draw(self: *Batcher) void {
        // draw all shapes from vertex data
        // todo: support multiple bindings to change textures / shader?
        if(self.num_draw_calls == 0) {
            graphics.setDrawColor(self.draw_color);
            graphics.draw(&self.bindings, &self.shader);
            return;
        }

        // for(0..self.num_draw_calls) |i| {
        //     self.bindings.setTexture(texture);
        //     // todo: split up draw call here!
        //     graphics.drawSubset(start, end, &self.bindings, &self.shader);
        // }
    }

    /// Expand the buffers for this batch if needed to fit the new size
    fn growBuffersToFit(self: *Batcher, needed_vertices: usize, needed_indices: usize) !void {
        if(needed_vertices > max_vertices or needed_indices > max_indices) {
            debug.log("Can't grow buffer to fit!: verts:{d} idxs:{d}", .{needed_vertices, needed_indices});
            return;
        }

        if(self.vertex_buffer.len < needed_vertices) {
            // debug.log("Growing vertex buffer to {d}", .{self.vertex_buffer.len * 2});
            self.vertex_buffer = batch_allocator.realloc(self.vertex_buffer, self.vertex_buffer.len * 2) catch {
                debug.log("Could not allocate needed vertices! Needed {d}", .{needed_vertices});
                return;
            };
        }
        if(self.index_buffer.len < needed_indices) {
            // debug.log("Growing index buffer to {d}", .{self.index_buffer.len * 2});
            self.index_buffer = batch_allocator.realloc(self.index_buffer, self.index_buffer.len * 2) catch {
                debug.log("Could not allocate needed indices! Needed {d}", .{needed_indices});
                return;
            };
        }
    }
};
