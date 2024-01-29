const std = @import("std");
const graphics = @import("../platform/graphics.zig");
const debug = @import("../debug.zig");
const zmesh = @import("zmesh");
const math = @import("../math.zig");

const Vertex = graphics.Vertex;

var mesh_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = mesh_gpa.allocator();

// Default vertex and fragment shader params
const VSParams = graphics.VSDefaultUniforms;
const FSParams = graphics.FSDefaultUniforms;

const vertex_layout = getVertexLayout();

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
            debug.log("Could not load mesh file {s}", .{filename});
            return null;
        };

        defer zmesh.io.freeData(data);

        var mesh_indices = std.ArrayList(u32).init(allocator);
        var mesh_positions = std.ArrayList([3]f32).init(allocator);
        var mesh_normals = std.ArrayList([3]f32).init(allocator);
        var mesh_texcoords = std.ArrayList([2]f32).init(allocator);
        var mesh_tangents = std.ArrayList([4]f32).init(allocator);

        defer mesh_indices.deinit();
        defer mesh_positions.deinit();
        defer mesh_normals.deinit();
        defer mesh_texcoords.deinit();

        zmesh.io.appendMeshPrimitive(
            data, // *zmesh.io.cgltf.Data
            0, // mesh index
            0, // gltf primitive index (submesh index)
            &mesh_indices,
            &mesh_positions,
            &mesh_normals, // normals (optional)
            &mesh_texcoords, // texcoords (optional)
            &mesh_tangents, // tangents (optional)
        ) catch {
            debug.log("Could not process mesh file!", .{});
            return null;
        };

        debug.log("Loaded mesh file {s} with {d} indices", .{ filename, mesh_indices.items.len });

        var vertices = allocator.alloc(Vertex, mesh_positions.items.len) catch {
            debug.log("Could not process mesh file!", .{});
            return null;
        };

        for (mesh_positions.items, mesh_texcoords.items, 0..) |vert, texcoord, i| {
            vertices[i].x = vert[0];
            vertices[i].y = vert[1];
            vertices[i].z = vert[2];
            vertices[i].u = texcoord[0];
            vertices[i].v = texcoord[1];
        }

        var material: graphics.Material = undefined;
        if (cfg.material == null) {
            var tex = graphics.createDebugTexture();
            material = graphics.Material.init(.{ .texture_0 = tex });
        } else {
            material = cfg.material.?;
        }

        return createMesh(vertices, mesh_indices.items, mesh_normals.items, mesh_tangents.items, material);
    }

    pub fn deinit(self: *Mesh) void {
        self.bindings.destroy();
    }

    pub fn draw(self: *Mesh, proj_view_matrix: math.Mat4, model_matrix: math.Mat4) void {
        graphics.drawWithMaterial(&self.bindings, &self.material, proj_view_matrix, model_matrix);
    }
};

/// Create a mesh out of some vertex data
pub fn createMesh(vertices: []graphics.Vertex, indices: []u32, normals: [][3]f32, tangents: [][4]f32, material: graphics.Material) Mesh {
    var bindings = graphics.Bindings.init(.{
        .index_len = indices.len,
        .vert_len = vertices.len,
        .vertex_layout = vertex_layout,
    });

    bindings.set(vertices, indices, normals, tangents, indices.len);

    const m: Mesh = Mesh{
        .bindings = bindings,
        .material = material,
    };
    return m;
}

/// Returns the vertex layout used by meshes
pub fn getVertexLayout() graphics.VertexLayout {
    return graphics.VertexLayout{
        .attributes = &[_]graphics.VertexLayoutAttribute{
            .{ .binding = .VERT_PACKED, .buffer_slot = 0, .item_size = @sizeOf(Vertex) },
            .{ .binding = .VERT_NORMALS, .buffer_slot = 1, .item_size = @sizeOf([3]f32) },
            .{ .binding = .VERT_TANGENTS, .buffer_slot = 2, .item_size = @sizeOf([4]f32) },
        },
    };
}

/// Returns the default shader attribute layout used by meshes
pub fn getShaderAttributes() []const graphics.ShaderAttribute {
    return &[_]graphics.ShaderAttribute{
        .{ .name = "pos", .attr_type = .FLOAT3, .binding = .VERT_PACKED },
        .{ .name = "color0", .attr_type = .UBYTE4N, .binding = .VERT_PACKED },
        .{ .name = "texcoord0", .attr_type = .FLOAT2, .binding = .VERT_PACKED },
        .{ .name = "normals", .attr_type = .FLOAT3, .binding = .VERT_NORMALS },
        .{ .name = "tangents", .attr_type = .FLOAT4, .binding = .VERT_TANGENTS },
    };
}
