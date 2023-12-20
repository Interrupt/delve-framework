
const graphics = @import("../platform/graphics.zig");
const std = @import("std");

var batch_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var batch_allocator = batch_gpa.allocator();

const Vertex = graphics.Vertex;

const max_indices = 32000;
const max_vertices = max_indices;

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
            .vertex_buffer = try batch_allocator.alloc(Vertex, max_vertices),
            .index_buffer = try batch_allocator.alloc(u16, max_indices),
            .bindings = graphics.Bindings.init(true),
        };

        return batcher;
    }

    pub fn deinit() void {
        // todo: dealloc here
    }

    /// Add a rectangle to the batch
    pub fn addRectangle(self: *Batcher, x: f32, y: f32, z: f32, width: f32, height: f32) void {
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

        // todo: adjust buffer sizes automatically, starting small and growing by powers of two
    }

    /// Add a rectangle to the batch
    pub fn addTriangle(self: *Batcher, x: f32, y: f32, z: f32, width: f32, height: f32) void {
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

        // todo: adjust buffer sizes automatically, starting small and growing by powers of two
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
};
