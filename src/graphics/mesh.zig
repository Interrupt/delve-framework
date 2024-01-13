
const std = @import("std");
const graphics = @import("../platform/graphics.zig");
const debug = @import("../debug.zig");
const zmesh = @import("zmesh");
const math = @import("../math.zig");

const Vertex = graphics.Vertex;

var mesh_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = mesh_gpa.allocator();

pub const MeshConfig = struct {
    material: ?graphics.Material = null,
};

pub const Mesh = struct {
    bindings: graphics.Bindings = undefined,
    material: graphics.Material = undefined,

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

        var bindings = graphics.Bindings.init(.{
            .index_len = mesh_indices.items.len,
            .vert_len = mesh_positions.items.len
        });

        bindings.set(vertices, mesh_indices.items , mesh_indices.items.len);

        var material: graphics.Material = undefined;
        if(cfg.material == null) {
            var tex = graphics.createDebugTexture();
            material = graphics.Material.init(.{ .texture_0 = tex });
        } else {
            material = cfg.material.?;
        }

        return Mesh{ .bindings = bindings, .material = material};
    }

    pub fn deinit(self: *Mesh) void {
        self.bindings.destroy();
    }

    pub fn draw(self: *Mesh) void {
        // Make our default uniform blocks
        const VSParams = struct {
            mvp: math.Mat4 align(16),
            in_color: [4]f32 align(16),
        };

        const FSParams = struct {
            in_color_override: [4]f32 align(16),
        };

        const vs_params = VSParams {
            .mvp = graphics.state.projection.mul(graphics.state.view).mul(graphics.state.model),
            .in_color = self.material.params.draw_color.toArray(),
        };

        const fs_params = FSParams {
            .in_color_override = self.material.params.color_override.toArray(),
        };

        // set our shader params
        self.material.shader.setUniformBlock(.FS, 0, graphics.asAnything(&fs_params));
        self.material.shader.setUniformBlock(.VS, 0, graphics.asAnything(&vs_params));

        graphics.drawWithMaterial(&self.bindings, &self.material);
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
