
const std = @import("std");
const graphics = @import("../platform/graphics.zig");
const debug = @import("../debug.zig");
const zmesh = @import("zmesh");

const Vertex = graphics.Vertex;

var mesh_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = mesh_gpa.allocator();

pub const MeshConfig = struct {
    texture: ?graphics.Texture = null,
    shader: ?graphics.Shader = null,
};

pub const Mesh = struct {
    bindings: graphics.Bindings = undefined,
    texture: graphics.Texture = undefined,
    shader: graphics.Shader = undefined,

    pub fn initFromFile(filename: [:0]const u8, cfg: MeshConfig) ?Mesh {
        zmesh.init(allocator);
        defer zmesh.deinit();

        const data = zmesh.io.parseAndLoadFile(filename) catch {
            debug.log("Could not load mesh file {s}", .{ filename });
            return null;
        };

        defer zmesh.io.freeData(data);

        var mesh_indices = std.ArrayList(u32).init(allocator);
        var mesh_positions = std.ArrayList([3]f32).init(allocator);
        var mesh_texcoords = std.ArrayList([2]f32).init(allocator);

        zmesh.io.appendMeshPrimitive(
            data, // *zmesh.io.cgltf.Data
            0, // mesh index
            0, // gltf primitive index (submesh index)
            &mesh_indices,
            &mesh_positions,
            null, // normals (optional)
            &mesh_texcoords, // texcoords (optional)
            null, // tangents (optional)
        ) catch {
            debug.log("Could not process mesh file!", .{});
            return null;
        };

        debug.log("Loaded mesh file {s} with {d} indices", .{ filename, mesh_indices.items.len });

        var vertices = allocator.alloc(Vertex, mesh_positions.items.len) catch {
            debug.log("Could not process mesh file!", .{});
            return null;
        };

        for(mesh_positions.items, mesh_texcoords.items, 0..) |vert, texcoord, i| {
            vertices[i].x = vert[0];
            vertices[i].y = vert[1];
            vertices[i].z = vert[2];
            vertices[i].u = texcoord[0];
            vertices[i].v = texcoord[1];
        }

        var bindings = graphics.Bindings.init(.{.index_len = mesh_indices.items.len, .vert_len = mesh_positions.items.len});
        bindings.set(vertices, mesh_indices.items , mesh_indices.items.len);

        var tex = if(cfg.texture != null) cfg.texture.? else graphics.createDebugTexture();
        var shd = if(cfg.shader != null) cfg.shader.? else graphics.Shader.init(.{ .cull_mode = .BACK, .index_size = .UINT32});

        return Mesh{ .bindings = bindings, .shader = shd, .texture = tex};
    }

    pub fn deinit(self: *Mesh) void {
        self.bindings.destroy();
    }

    pub fn draw(self: *Mesh) void {
        self.bindings.setTexture(self.texture);
        graphics.draw(&self.bindings, &self.shader);
    }
};

pub fn createMesh(vertices: []graphics.Vertex, indices: []u32) Mesh {
    const m: Mesh = Mesh {
        .bindings = graphics.Bindings{
            .vertex_buffer = vertices,
            .index_buffer = indices,
            .bindings = *graphics.createBindings(vertices, indices),
        },
    };
    return m;
}
