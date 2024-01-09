
const std = @import("std");
const graphics = @import("../platform/graphics.zig");
const debug = @import("../debug.zig");
const zmesh = @import("zmesh");

const Vertex = graphics.Vertex;

var mesh_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = mesh_gpa.allocator();

pub const Mesh = struct {
    bindings: graphics.Bindings = undefined,
    shader: graphics.Shader = undefined,

    pub fn init(filename: [:0]const u8) ?Mesh {
        zmesh.init(allocator);
        defer zmesh.deinit();

        const data = zmesh.io.parseAndLoadFile(filename) catch {
            debug.log("Could not load mesh file {s}", .{ filename });
            return null;
        };

        defer zmesh.io.freeData(data);

        var mesh_indices = std.ArrayList(u32).init(allocator);
        var mesh_positions = std.ArrayList([3]f32).init(allocator);
        var mesh_normals = std.ArrayList([3]f32).init(allocator);

        zmesh.io.appendMeshPrimitive(
            data, // *zmesh.io.cgltf.Data
            0, // mesh index
            0, // gltf primitive index (submesh index)
            &mesh_indices,
            &mesh_positions,
            &mesh_normals, // normals (optional)
            null, // texcoords (optional)
            null, // tangents (optional)
        ) catch {
            debug.log("Could not process mesh file!", .{});
            return null;
        };

        debug.log("  mesh has {d} verts and {d} indices", .{mesh_positions.items.len, mesh_indices.items.len});

        debug.log("Loaded mesh file {s}", .{ filename });
        var vertices = allocator.alloc(Vertex, mesh_positions.items.len) catch {
            debug.log("Could not process mesh file!", .{});
            return null;
        };

        for(mesh_positions.items, 0..) |v, i| {
            vertices[i].x = v[0];
            vertices[i].y = v[1];
            vertices[i].z = v[2];
        }

        var bindings = graphics.Bindings.init(.{.index_len = mesh_indices.items.len, .vert_len = mesh_positions.items.len});
        bindings.set(vertices, mesh_indices.items , mesh_indices.items.len);
        bindings.setTexture(graphics.tex_grey);

        return Mesh{ .bindings = bindings, .shader = graphics.Shader.init(.{}) };
    }

    pub fn deinit(self: *Mesh) void {
        self.bindings.destroy();
    }

    // pub fn draw(self: *Batcher) void {
    //     if(self.index_pos == 0)
    //         return;
    //
    //     graphics.draw(&self.bindings, &self.shader);
    // }
};

pub fn createMesh(vertices: []graphics.Vertex, indices: []u16) Mesh {
    const m: Mesh = Mesh {
        .bindings = graphics.Bindings{
            .vertex_buffer = vertices,
            .index_buffer = indices,
            .bindings = *graphics.createBindings(vertices, indices),
        },
    };
    return m;
}
