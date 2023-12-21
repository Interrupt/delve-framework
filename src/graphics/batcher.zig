
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const images = @import("../images.zig");
const std = @import("std");

var batch_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var batch_allocator = batch_gpa.allocator();

const Vertex = graphics.Vertex;

const max_indices = 64000;
const max_vertices = max_indices;

const min_indices = 32;
const min_vertices = min_indices;

pub const Batcher = struct {
    vertex_buffer: []Vertex,
    index_buffer: []u16,
    vertex_pos: usize,
    index_pos: usize,
    bindings: graphics.Bindings,

    pub fn init() !Batcher {
        var batcher: Batcher = Batcher {
            .vertex_pos = 0,
            .index_pos = 0,
            .vertex_buffer = try batch_allocator.alloc(Vertex, min_vertices),
            .index_buffer = try batch_allocator.alloc(u16, min_indices),
            .bindings = graphics.Bindings.init(.{.updatable = true, .index_len = 64000, .vert_len = 64000}),
        };

        // create a small debug checker-board texture
        const img = &[4 * 4]u32{
            0xFFFFFFFF, 0xFFFF0000, 0xFF333333, 0xFF000000,
            0xFF000000, 0xFFFFFFFF, 0xFF00FF00, 0xFFFFFFFF,
            0xFFFFFFFF, 0xFF000000, 0xFF333333, 0xFF0000FF,
            0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFF333333,
        };
        batcher.bindings.setImage(img, 4, 4);

        return batcher;
    }

    pub fn deinit() void {
        // todo: dealloc here
    }

    pub fn setImage(self: *Batcher, image: *images.Image) void {
        self.bindings.setImage(image.raw, image.width, image.height);
    }

    /// Add a rectangle to the batch
    pub fn addRectangle(self: *Batcher, x: f32, y: f32, z: f32, width: f32, height: f32) void {
        self.growBuffersToFit(self.vertex_pos + 4, self.index_pos + 6) catch {
            return;
        };

        const verts = &[_]Vertex{
            .{ .x = x, .y = y + height, .z = z, .color = 0xFFFFFFFF, .u = 0, .v = 0 },
            .{ .x = x + width, .y = y + height, .z = z, .color = 0xFFFFFFFF, .u = 6550, .v = 0 },
            .{ .x = x + width, .y = y, .z = z, .color = 0xFFFFFFFF, .u = 6550, .v = 6550},
            .{ .x = x, .y = y, .z = z, .color = 0xFFFFFFFF, .u = 0, .v = 6550},
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

    /// Add a rectangle to the batch
    pub fn addTriangle(self: *Batcher, x: f32, y: f32, z: f32, width: f32, height: f32) void {
        self.growBuffersToFit(self.vertex_pos + 3, self.index_pos + 3) catch {
            return;
        };

        const verts = &[_]Vertex{
            .{ .x = x + width / 2.0, .y = y + height, .z = z, .color = 0xFFFFFFFF, .u = 3275, .v = 0},
            .{ .x = x, .y = y, .z = z, .color = 0xFFFFFFFF, .u = 0, .v = 6550},
            .{ .x = x + width, .y = y, .z = z, .color = 0xFFFFFFFF, .u = 6550, .v = 6550},
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

    pub fn apply(self: *Batcher) void {
        self.bindings.update(self.vertex_buffer, self.index_buffer, self.vertex_pos, self.index_pos);
    }

    pub fn reset(self: *Batcher) void {
        self.vertex_pos = 0;
        self.index_pos = 0;
    }

    pub fn draw(self: *Batcher) void {
        // draw all shapes from vertex data
        // todo: support multiple bindings to change textures?
        graphics.draw(self.bindings);
    }

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
