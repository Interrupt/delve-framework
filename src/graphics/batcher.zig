
const graphics = @import("../platform/graphics.zig");
const std = @import("std");

var batch_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var batch_allocator = batch_gpa.allocator();

const Vertex = graphics.Vertex;

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
            .vertex_buffer = try batch_allocator.alloc(Vertex, 32000),
            .index_buffer = try batch_allocator.alloc(u16, 32000),
            .bindings = graphics.Bindings.init(),
        };

        return batcher;
    }

    pub fn deinit() void {

    }

    pub fn addRectangle(self: *Batcher, x: f32, y: f32, z: f32, width: f32, height: f32) void {
        // add rectangle vertices to batch
        const verts = &[_]Vertex{
            .{ .x = x, .y = y + height, .z = z, .color = 0xFFFFFFFF, .u = 0, .v = 0 },
            .{ .x = x + width, .y = y + height, .z = z, .color = 0xFFFFFFFF, .u = 6550, .v = 0 },
            .{ .x = x + width, .y = y, .z = z, .color = 0xFFFFFFFF, .u = 6550, .v = 6550},
            .{ .x = x, .y = y, .z = z, .color = 0xFFFFFFFF, .u = 0, .v = 6550},
        };

        // rectangler indices
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

        self.bindings.update(self.vertex_buffer, self.index_buffer, self.index_pos);
    }

    // pub fn addTriangle(self: *Batcher, x: f32, y: f32, width: f32, height: f32) void {
    //     _ = x;
    //     _ = y;
    //     _ = width;
    //     _ = height;
    //
    //     // add tri vertices to batch
    //     const verts = &[_]Vertex{
    //         .{ .x = 0.0, .y = 0.5, .z = 0.0, .color = 0xFFFFFFFF, .u = 0, .v = 0 },
    //         .{ .x = 0.5, .y = -0.5, .z = 0.0, .color = 0xFFFFFFFF, .u = 32767, .v = 0 },
    //         .{ .x = -0.5, .y = -0.5, .z = 0.0, .color = 0xFF111111, .u = 32767, .v = 32767 },
    //     };
    //
    //     // rectangler indices
    //     const indices = &[_]u16{ 0, 1, 2 };
    //
    //     self.bindings.update(verts, indices, 3);
    // }

    pub fn draw(self: *Batcher) void {
        // draw all vertex data
        // next: save positions of state changes (like textures, shaders, view matrix)
        graphics.draw(self.bindings);
    }
};
