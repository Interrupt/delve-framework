const std = @import("std");
const graphics = @import("../platform/graphics.zig");
const debug = @import("../debug.zig");
const zmesh = @import("zmesh");
const math = @import("../math.zig");
const mem = @import("../mem.zig");
const colors = @import("../colors.zig");
const boundingbox = @import("../spatial/boundingbox.zig");
const zmeshutils = @import("../utils/zmesh.zig");

const ArrayList = std.array_list.Managed;
const ArrayListUnmanaged = std.ArrayList;

const PackedVertex = graphics.PackedVertex;
const Vertex = graphics.Vertex;
const CameraMatrices = graphics.CameraMatrices;
const Color = colors.Color;
const Rect = @import("../spatial/rect.zig").Rect;
const Frustum = @import("../spatial/frustum.zig").Frustum;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Vec2 = math.Vec2;

// Default vertex and fragment shader params
const VSParams = graphics.VSDefaultUniforms;
const FSParams = graphics.FSDefaultUniforms;

const vertex_layout = getVertexLayout();

pub const MeshConfig = struct {
    materials: std.ArrayList(graphics.Material),
};

pub fn init() !void {
    zmesh.init(mem.getAllocator());
}

pub fn deinit() void {
    defer zmesh.deinit();
}

/// A mesh is a drawable set of vertex positions, normals, tangents, and uvs.
/// These can be created on the fly, using a MeshBuilder, or loaded from GLTF files.
pub const Mesh = struct {
    bindings_list: std.ArrayList(graphics.Bindings) = undefined,
    materials: std.ArrayList(graphics.Material) = undefined,
    bounds: boundingbox.BoundingBox = undefined,

    has_skin: bool = false,

    zmesh_data: ?*zmesh.io.zcgltf.Data = null,

    pub fn initFromData(allocator: std.mem.Allocator, data: *zmesh.io.zcgltf.Data, mesh_index: usize, cfg: MeshConfig) ?Mesh {
        var bindings_list = std.ArrayList(graphics.Bindings).init(allocator);

        var vertices = std.ArrayList(PackedVertex).init(allocator);
        defer vertices.deinit();

        var any_submesh_had_joints: bool = false;

        // vertices is global but need partial for each bindings
        var vertices_start: usize = 0;

        const mesh = data.meshes.?[mesh_index];
        for (0..mesh.primitives_count) |primitive_index| {
            var mesh_indices = std.ArrayList(u32).init(allocator);
            var mesh_positions = std.ArrayList([3]f32).init(allocator);
            var mesh_normals = std.ArrayList([3]f32).init(allocator);
            var mesh_texcoords = std.ArrayList([2]f32).init(allocator);
            var mesh_tangents = std.ArrayList([4]f32).init(allocator);

            var mesh_joints = std.ArrayList([4]f32).init(allocator);
            var mesh_weights = std.ArrayList([4]f32).init(allocator);

            defer mesh_indices.deinit();
            defer mesh_positions.deinit();
            defer mesh_normals.deinit();
            defer mesh_texcoords.deinit();
            defer mesh_tangents.deinit();
            defer mesh_joints.deinit();
            defer mesh_weights.deinit();

            zmesh.io.appendMeshPrimitive(
                data, // *zmesh.io.cgltf.Data
                @intCast(mesh_index), // mesh index
                @intCast(primitive_index), // gltf primitive index (submesh index)
                &mesh_indices,
                &mesh_positions,
                &mesh_normals, // normals (optional)
                &mesh_texcoords, // texcoords (optional)
                &mesh_tangents, // tangents (optional)
                &mesh_joints, // joints (optional)
                &mesh_weights, // weights (optional)
            ) catch {
                debug.log("Could not process mesh file!", .{});
                return null;
            };

            const white_color = colors.white.toArray();

            for (mesh_positions.items, 0..) |vert, i| {
                var u_textcoord: f32 = 0.0;
                var v_textcoord: f32 = 0.0;

                if (mesh_texcoords.items.len > i) {
                    u_textcoord = mesh_texcoords.items[i][0];
                    v_textcoord = mesh_texcoords.items[i][1];
                }

                vertices.append(.{ .x = vert[0], .y = vert[1], .z = vert[2], .u = u_textcoord, .v = v_textcoord, .color = white_color }) catch {
                    debug.log("Could not process mesh file!", .{});
                    return null;
                };
            }

            // Fill in normals if none were given, to match vertex layout
            if (mesh_normals.items.len == 0) {
                for (0..mesh_positions.items.len) |_| {
                    const empty = [3]f32{ 0.0, 0.0, 0.0 };
                    mesh_normals.append(empty) catch {
                        return null;
                    };
                }
            }

            // Fill in tangents if none were given, to match vertex layout
            if (mesh_tangents.items.len == 0) {
                for (0..mesh_positions.items.len) |_| {
                    const empty = [4]f32{ 0.0, 0.0, 0.0, 0.0 };
                    mesh_tangents.append(empty) catch {
                        return null;
                    };
                }
            }

            // Fill in joints, if none were given, to match vertex layout
            any_submesh_had_joints = mesh_joints.items.len > 0 and mesh_weights.items.len > 0;

            var bindings: graphics.Bindings = undefined;

            if (any_submesh_had_joints) {
                debug.log("Creating skinned mesh: {d} indices", .{mesh_indices.items.len});

                const layout = getSkinnedVertexLayout();
                bindings = graphics.Bindings.init(.{
                    .index_len = mesh_indices.items.len,
                    .vert_len = vertices.items.len,
                    .vertex_layout = layout,
                });

                bindings.setWithJoints(vertices.items[vertices_start..], mesh_indices.items, mesh_normals.items, mesh_tangents.items, mesh_joints.items, mesh_weights.items, mesh_indices.items.len);
            } else {
                bindings = graphics.Bindings.init(.{
                    .index_len = mesh_indices.items.len,
                    .vert_len = vertices.items.len,
                    .vertex_layout = vertex_layout,
                });

                bindings.set(vertices.items[vertices_start..], mesh_indices.items, mesh_normals.items, mesh_tangents.items, mesh_indices.items.len);
            }

            bindings_list.append(bindings) catch {
                return null;
            };

            vertices_start = vertices.items.len;
        }

        if (any_submesh_had_joints) {
            return createSkinnedMesh(vertices.items, bindings_list, cfg.materials, data);
        }

        return createMesh(vertices.items, bindings_list, cfg.materials);
    }

    pub fn deinit(self: *Mesh) void {
        for (self.bindings_list.items) |*b| {
            b.destroy();
        }
        self.bindings_list.deinit();
    }

    /// Draw this mesh
    pub fn draw(self: *Mesh, cam_matrices: CameraMatrices, model_matrix: math.Mat4) void {
        for (self.bindings_list.items, self.materials.items) |*bindings, *material| {
            graphics.drawWithMaterial(bindings, material, cam_matrices, model_matrix);
        }
    }

    /// Draw this mesh, using the specified materials instead of the set ones
    pub fn drawWithMaterials(self: *Mesh, materials: []graphics.Material, cam_matrices: CameraMatrices, model_matrix: math.Mat4) void {
        for (self.bindings_list.items, materials) |*bindings, *material| {
            graphics.drawWithMaterial(bindings, material, cam_matrices, model_matrix);
        }
    }
};

/// Create a mesh out of some vertex data
pub fn createMesh(vertices: []PackedVertex, bindings_list: std.ArrayList(graphics.Bindings), materials: std.ArrayList(graphics.Material)) Mesh {
    // create a mesh with the default vertex layout

    const m: Mesh = Mesh{
        .bindings_list = bindings_list,
        .materials = materials,
        .bounds = boundingbox.BoundingBox.initFromVerts(vertices),
    };
    return m;
}

pub fn createSkinnedMesh(vertices: []PackedVertex, bindings_list: std.ArrayList(graphics.Bindings), materials: std.ArrayList(graphics.Material), data: *zmesh.io.zcgltf.Data) Mesh {
    // create a mesh with the default vertex layout
    // debug.log("Creating skinned mesh: {d} indices, {d} normals, {d}tangents, {d} joints, {d} weights", .{ indices.len, normals.len, tangents.len, joints.len, weights.len });

    const m: Mesh = Mesh{
        .bindings_list = bindings_list,
        .materials = materials,
        .bounds = boundingbox.BoundingBox.initFromVerts(vertices),
        .zmesh_data = data,
        .has_skin = true,
    };
    return m;
}

/// Creates a cube using a mesh builder
pub fn createCube(pos: Vec3, size: Vec3, color: Color, material: graphics.Material) !Mesh {
    var builder = MeshBuilder.init(mem.getAllocator());
    defer builder.deinit();

    try builder.addCube(pos, size, math.Mat4.identity, color);

    return builder.buildMesh(material);
}

/// Returns the vertex layout used by meshes
pub fn getVertexLayout() graphics.VertexLayout {
    return graphics.VertexLayout{
        .attributes = &[_]graphics.VertexLayoutAttribute{
            .{ .binding = .VERT_PACKED, .buffer_slot = 0, .item_size = @sizeOf(PackedVertex) },
            .{ .binding = .VERT_NORMALS, .buffer_slot = 1, .item_size = @sizeOf([3]f32) },
            .{ .binding = .VERT_TANGENTS, .buffer_slot = 2, .item_size = @sizeOf([4]f32) },
        },
    };
}

pub fn getSkinnedVertexLayout() graphics.VertexLayout {
    return graphics.VertexLayout{
        .attributes = &[_]graphics.VertexLayoutAttribute{
            .{ .binding = .VERT_PACKED, .buffer_slot = 0, .item_size = @sizeOf(PackedVertex) },
            .{ .binding = .VERT_NORMALS, .buffer_slot = 1, .item_size = @sizeOf([3]f32) },
            .{ .binding = .VERT_TANGENTS, .buffer_slot = 2, .item_size = @sizeOf([4]f32) },
            .{ .binding = .VERT_JOINTS, .buffer_slot = 3, .item_size = @sizeOf([4]f32) },
            .{ .binding = .VERT_WEIGHTS, .buffer_slot = 4, .item_size = @sizeOf([4]f32) },
        },
    };
}

/// Returns the default shader attribute layout used by meshes
pub fn getShaderAttributes() []const graphics.ShaderAttribute {
    return &[_]graphics.ShaderAttribute{
        .{ .name = "pos", .attr_type = .FLOAT3, .binding = .VERT_PACKED },
        .{ .name = "color0", .attr_type = .FLOAT4, .binding = .VERT_PACKED },
        .{ .name = "texcoord0", .attr_type = .FLOAT2, .binding = .VERT_PACKED },
        .{ .name = "normals", .attr_type = .FLOAT3, .binding = .VERT_NORMALS },
        .{ .name = "tangents", .attr_type = .FLOAT4, .binding = .VERT_TANGENTS },
    };
}

pub fn getSkinnedShaderAttributes() []const graphics.ShaderAttribute {
    return &[_]graphics.ShaderAttribute{
        .{ .name = "pos", .attr_type = .FLOAT3, .binding = .VERT_PACKED },
        .{ .name = "color0", .attr_type = .FLOAT4, .binding = .VERT_PACKED },
        .{ .name = "texcoord0", .attr_type = .FLOAT2, .binding = .VERT_PACKED },
        .{ .name = "normals", .attr_type = .FLOAT3, .binding = .VERT_NORMALS },
        .{ .name = "tangents", .attr_type = .FLOAT4, .binding = .VERT_TANGENTS },
        .{ .name = "joints", .attr_type = .FLOAT4, .binding = .VERT_JOINTS },
        .{ .name = "weights", .attr_type = .FLOAT4, .binding = .VERT_WEIGHTS },
    };
}

/// MeshBuilder is a helper for making runtime meshes
pub const MeshBuilder = struct {
    vertices: std.ArrayList(PackedVertex) = undefined,
    indices: std.ArrayList(u32) = undefined,
    normals: std.ArrayList([3]f32) = undefined,
    tangents: std.ArrayList([4]f32) = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) MeshBuilder {
        return MeshBuilder{
            .vertices = std.ArrayList(PackedVertex).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
            .normals = std.ArrayList([3]f32).init(allocator),
            .tangents = std.ArrayList([4]f32).init(allocator),
            .allocator = allocator,
        };
    }

    /// Adds a quad to the mesh builder
    pub fn addQuad(self: *MeshBuilder, v0: Vec2, v1: Vec2, v2: Vec2, v3: Vec2, transform: math.Mat4, color: Color) !void {
        const u = 0.0;
        const v = 0.0;
        const u_2 = 1.0;
        const v_2 = 1.0;
        const color_array = color.toArray();

        const verts = &[_]PackedVertex{
            .{ .x = v0.x, .y = v0.y, .z = 0, .color = color_array, .u = u, .v = v_2 },
            .{ .x = v1.x, .y = v1.y, .z = 0, .color = color_array, .u = u_2, .v = v_2 },
            .{ .x = v2.x, .y = v2.y, .z = 0, .color = color_array, .u = u_2, .v = v },
            .{ .x = v3.x, .y = v3.y, .z = 0, .color = color_array, .u = u, .v = v },
        };

        const indices = &[_]u32{ 0, 1, 2, 0, 2, 3 };

        const v_pos = @as(u32, @intCast(self.vertices.items.len));
        const normal = Vec3.z_axis.mulMat4(transform).norm().toArray();
        const tangent = math.Vec4.new(1.0, 0.0, 0.0, 1.0).mulMat4(transform).toArray();

        for (verts) |vert| {
            try self.vertices.append(PackedVertex.mulMat4(vert, transform));
            try self.normals.append(normal);
            try self.tangents.append(tangent);
        }

        for (indices) |idx| {
            try self.indices.append(idx + v_pos);
        }
    }

    /// Adds a rectangle to the mesh builder
    pub fn addRect(self: *MeshBuilder, rect: Rect, transform: math.Mat4, color: Color) !void {
        const v0 = rect.getBottomLeft();
        const v1 = rect.getBottomRight();
        const v2 = rect.getTopRight();
        const v3 = rect.getTopLeft();

        try self.addQuad(v0, v1, v2, v3, transform, color);
    }

    /// Adds a triangle to the mesh builder
    pub fn addTriangle(self: *MeshBuilder, v0: Vec3, v1: Vec3, v2: Vec3, transform: math.Mat4, color: Color) !void {
        const u = 0.0;
        const v = 0.0;
        const u_2 = 1.0;
        const v_2 = 1.0;
        const color_a = color.toArray();

        const verts = &[_]PackedVertex{
            .{ .x = v0.x, .y = v0.y, .z = v0.z, .color = color_a, .u = u, .v = v_2 },
            .{ .x = v1.x, .y = v1.y, .z = v1.z, .color = color_a, .u = u_2, .v = v_2 },
            .{ .x = v2.x, .y = v2.y, .z = v2.z, .color = color_a, .u = u_2, .v = v },
        };

        const normal = v0.cross(v1).mulMat4(transform).norm().toArray();

        // todo: should the tangent get passed in?
        const tangent = math.Vec4.new(1.0, 0.0, 0.0, 1.0).mulMat4(transform).toArray();

        const indices = &[_]u32{ 0, 1, 2 };

        for (verts) |vert| {
            try self.vertices.append(PackedVertex.mulMat4(vert, transform));
            try self.normals.append(normal);
            try self.tangents.append(tangent);
        }

        const v_pos = @as(u32, @intCast(self.indices.items.len));
        for (indices) |idx| {
            try self.indices.append(idx + v_pos);
        }
    }

    /// Adds a triangle to the mesh builder, from vertices
    pub fn addTriangleFromPackedVertices(self: *MeshBuilder, v0: PackedVertex, v1: PackedVertex, v2: PackedVertex, transform: math.Mat4) !void {
        try self.vertices.append(PackedVertex.mulMat4(v0, transform));
        try self.vertices.append(PackedVertex.mulMat4(v1, transform));
        try self.vertices.append(PackedVertex.mulMat4(v2, transform));

        const normal = v0.getPosition().cross(v1.getPosition()).mulMat4(transform).norm().toArray();

        // todo: should the tangent get passed in?
        const tangent = math.Vec4.new(1.0, 0.0, 0.0, 1.0).mulMat4(transform).toArray();

        const indices = &[_]u32{ 0, 1, 2 };

        const v_pos = @as(u32, @intCast(self.indices.items.len));
        for (indices) |idx| {
            try self.indices.append(idx + v_pos);
            try self.normals.append(normal);
            try self.tangents.append(tangent);
        }
    }

    /// Adds a triangle to the mesh builder, from unpacked vertices
    pub fn addTriangleFromVertices(self: *MeshBuilder, v0: Vertex, v1: Vertex, v2: Vertex) !void {
        try self.vertices.append(v0.pack());
        try self.vertices.append(v1.pack());
        try self.vertices.append(v2.pack());

        try self.normals.append(v0.normal.toArray());
        try self.normals.append(v1.normal.toArray());
        try self.normals.append(v2.normal.toArray());

        try self.tangents.append(v0.tangent.toArray());
        try self.tangents.append(v1.tangent.toArray());
        try self.tangents.append(v2.tangent.toArray());

        const indices = &[_]u32{ 0, 1, 2 };
        const v_pos = @as(u32, @intCast(self.indices.items.len));
        for (indices) |idx| {
            try self.indices.append(idx + v_pos);
        }
    }

    pub fn addTriangleFromVerticesWithTransform(self: *MeshBuilder, v0: Vertex, v1: Vertex, v2: Vertex, transform: math.Mat4) !void {
        const v0_t = v0.mulMat4(transform);
        const v1_t = v1.mulMat4(transform);
        const v2_t = v2.mulMat4(transform);
        try self.addTriangleFromVertices(v0_t, v1_t, v2_t);
    }

    pub fn addCube(self: *MeshBuilder, pos: Vec3, size: Vec3, transform: math.Mat4, color: Color) !void {
        const rect_west = Rect.newCentered(math.Vec2.zero, math.Vec2.new(size.z, size.y));
        const rect_east = Rect.newCentered(math.Vec2.zero, math.Vec2.new(size.z, size.y));
        const rect_north = Rect.newCentered(math.Vec2.zero, math.Vec2.new(size.x, size.y));
        const rect_south = Rect.newCentered(math.Vec2.zero, math.Vec2.new(size.x, size.y));
        const rect_top = Rect.newCentered(math.Vec2.zero, math.Vec2.new(size.x, size.z));
        const rect_bottom = Rect.newCentered(math.Vec2.zero, math.Vec2.new(size.x, size.z));

        const rot_west = math.Mat4.rotate(-90, Vec3.y_axis);
        const rot_east = math.Mat4.rotate(90, Vec3.y_axis);
        const rot_north = math.Mat4.rotate(180, Vec3.y_axis);
        const rot_south = math.Mat4.rotate(0, Vec3.y_axis);
        const rot_top = math.Mat4.rotate(-90, Vec3.x_axis);
        const rot_bottom = math.Mat4.rotate(90, Vec3.x_axis);

        try self.addRect(rect_west, transform.mul(math.Mat4.translate(Vec3.new(pos.x - size.x * 0.5, pos.y, pos.z)).mul(rot_west)), color);
        try self.addRect(rect_east, transform.mul(math.Mat4.translate(Vec3.new(pos.x + size.x * 0.5, pos.y, pos.z)).mul(rot_east)), color);
        try self.addRect(rect_north, transform.mul(math.Mat4.translate(Vec3.new(pos.x, pos.y, pos.z - size.z * 0.5)).mul(rot_north)), color);
        try self.addRect(rect_south, transform.mul(math.Mat4.translate(Vec3.new(pos.x, pos.y, pos.z + size.z * 0.5)).mul(rot_south)), color);
        try self.addRect(rect_top, transform.mul(math.Mat4.translate(Vec3.new(pos.x, pos.y + size.y * 0.5, pos.z)).mul(rot_top)), color);
        try self.addRect(rect_bottom, transform.mul(math.Mat4.translate(Vec3.new(pos.x, pos.y - size.y * 0.5, pos.z)).mul(rot_bottom)), color);
    }

    pub fn addFrustum(self: *MeshBuilder, frustum: Frustum, transform: math.Mat4, color: Color) !void {
        const corners = frustum.corners;

        // front
        try self.addTriangle(corners[0], corners[1], corners[2], transform, color);
        try self.addTriangle(corners[2], corners[1], corners[3], transform, color);

        // back
        try self.addTriangle(corners[6], corners[5], corners[4], transform, color);
        try self.addTriangle(corners[7], corners[5], corners[6], transform, color);

        // left
        try self.addTriangle(corners[4], corners[1], corners[0], transform, color);
        try self.addTriangle(corners[4], corners[5], corners[1], transform, color);

        // right
        try self.addTriangle(corners[2], corners[3], corners[6], transform, color);
        try self.addTriangle(corners[6], corners[3], corners[7], transform, color);

        // top
        try self.addTriangle(corners[5], corners[3], corners[1], transform, color);
        try self.addTriangle(corners[7], corners[3], corners[5], transform, color);

        // bottom
        try self.addTriangle(corners[0], corners[2], corners[4], transform, color);
        try self.addTriangle(corners[4], corners[2], corners[6], transform, color);
    }

    /// Bakes a mesh out of the mesh builder from the current state
    pub fn buildMesh(self: *const MeshBuilder, material: graphics.Material) !Mesh {
        var bindings = graphics.Bindings.init(.{
            .index_len = self.indices.items.len,
            .vert_len = self.vertices.items.len,
            .vertex_layout = vertex_layout,
        });

        bindings.set(self.vertices.items, self.indices.items, self.normals.items, self.tangents.items, self.indices.items.len);

        var bindings_list = std.ArrayList(graphics.Bindings).init(self.allocator);
        try bindings_list.append(bindings);
        var materials = std.ArrayList(graphics.Material).init(self.allocator);
        try materials.append(material);

        return createMesh(self.vertices.items, bindings_list, materials);
    }

    /// Cleans up a mesh builder
    pub fn deinit(self: *MeshBuilder) void {
        // maybe use arena here
        self.vertices.deinit();
        self.indices.deinit();
        self.normals.deinit();
        self.tangents.deinit();
    }
};
