const std = @import("std");
const graphics = @import("../platform/graphics.zig");
const debug = @import("../debug.zig");
const zmesh = @import("zmesh");
const math = @import("../math.zig");
const mem = @import("../mem.zig");
const colors = @import("../colors.zig");
const boundingbox = @import("../spatial/boundingbox.zig");

const Vertex = graphics.Vertex;
const Color = colors.Color;
const Rect = @import("../spatial/rect.zig").Rect;
const Frustum = @import("../spatial/frustum.zig").Frustum;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;

// Default vertex and fragment shader params
const VSParams = graphics.VSDefaultUniforms;
const FSParams = graphics.FSDefaultUniforms;

const vertex_layout = getVertexLayout();

pub const MeshConfig = struct {
    material: ?graphics.Material = null,
};

/// A mesh is a drawable set of vertex positions, normals, tangents, and uvs.
/// These can be created on the fly, using a MeshBuilder, or loaded from GLTF files.
pub const Mesh = struct {
    bindings: graphics.Bindings = undefined,
    material: graphics.Material = undefined,
    bounds: boundingbox.BoundingBox = undefined,
    zmesh_data: *zmesh.io.zcgltf.Data = undefined,
    joint_locations: [64]math.Mat4 = [_]math.Mat4{math.Mat4.identity} ** 64,

    pub fn initFromFile(allocator: std.mem.Allocator, filename: [:0]const u8, cfg: MeshConfig) ?Mesh {
        zmesh.init(allocator);
        // defer zmesh.deinit();

        const data = zmesh.io.parseAndLoadFile(filename) catch {
            debug.log("Could not load mesh file {s}", .{filename});
            return null;
        };

        // defer zmesh.io.freeData(data);

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

        zmesh.io.appendMeshPrimitive(
            data, // *zmesh.io.cgltf.Data
            0, // mesh index
            0, // gltf primitive index (submesh index)
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

        debug.log("Loaded mesh file {s} with {d} indices", .{ filename, mesh_indices.items.len });

        var vertices = allocator.alloc(Vertex, mesh_positions.items.len) catch {
            debug.log("Could not process mesh file!", .{});
            return null;
        };

        for (mesh_positions.items, 0..) |vert, i| {
            vertices[i].x = vert[0];
            vertices[i].y = vert[1];
            vertices[i].z = vert[2];

            if (mesh_texcoords.items.len > i) {
                vertices[i].u = mesh_texcoords.items[i][0];
                vertices[i].v = mesh_texcoords.items[i][1];
            } else {
                vertices[i].u = 0.0;
                vertices[i].v = 0.0;
            }
        }

        var material: graphics.Material = undefined;
        if (cfg.material == null) {
            const tex = graphics.createDebugTexture();
            material = graphics.Material.init(.{ .texture_0 = tex });
        } else {
            material = cfg.material.?;
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

        if (mesh_joints.items.len == 0) {
            for (0..mesh_positions.items.len) |_| {
                const empty = [4]f32{ 0.0, 0.0, 0.0, 0.0 };
                mesh_joints.append(empty) catch {
                    return null;
                };
            }
        }

        if (mesh_weights.items.len == 0) {
            for (0..mesh_positions.items.len) |_| {
                const empty = [4]f32{ 0.0, 0.0, 0.0, 0.0 };
                mesh_weights.append(empty) catch {
                    return null;
                };
            }
        }

        debug.log("Found {d} joints in mesh", .{mesh_joints.items.len});
        debug.log("Found {d} weights in mesh", .{mesh_weights.items.len});

        return createSkinnedMesh(vertices, mesh_indices.items, mesh_normals.items, mesh_tangents.items, mesh_joints.items, mesh_weights.items, material, data);
    }

    pub fn deinit(self: *Mesh) void {
        self.bindings.destroy();
    }

    /// Draw this mesh
    pub fn draw(self: *Mesh, proj_view_matrix: math.Mat4, model_matrix: math.Mat4) void {
        graphics.drawWithMaterial(&self.bindings, &self.material, proj_view_matrix, model_matrix);
    }

    /// Draw this mesh, using the specified material instead of the set one
    pub fn drawWithMaterial(self: *Mesh, material: *graphics.Material, proj_view_matrix: math.Mat4, model_matrix: math.Mat4) void {
        graphics.drawWithMaterial(&self.bindings, material, proj_view_matrix, model_matrix);
    }

    pub fn sampleAnimation(self: *Mesh, sampler: *zmesh.io.zcgltf.AnimationSampler, t: f32) math.Vec3 {
        _ = self;

        const samples = zmesh.io.getAnimationSamplerData(sampler.input);
        const data = zmesh.io.getAnimationSamplerData(sampler.output);

        switch (sampler.interpolation) {
            .step => {
                // debug.log("Step animation!", .{});
                return access(math.Vec3, data, stepInterpolation(samples, t));
            },
            .linear => {
                // debug.log("Lerp animation!", .{});
                const r = linearInterpolation(samples, t);
                const v0 = access(math.Vec3, data, r.prev_i);
                const v1 = access(math.Vec3, data, r.next_i);
                return math.Vec3.lerp(v0, v1, r.alpha);
            },
            .cubic_spline => {
                @panic("Cubicspline in animations not implemented!");
            },
        }
    }

    /// Returns the index of the last sample less than `t`.
    fn stepInterpolation(samples: []const f32, t: f32) usize {
        std.debug.assert(samples.len > 0);
        const S = struct {
            fn lessThan(_: void, lhs: f32, rhs: f32) bool {
                return lhs < rhs;
            }
        };
        const i = std.sort.lowerBound(f32, t, samples, {}, S.lessThan);
        return if (i > 0) i - 1 else 0;
    }

    /// Returns the indices of the samples around `t` and `alpha` to interpolate between those.
    fn linearInterpolation(samples: []const f32, t: f32) struct {
        prev_i: usize,
        next_i: usize,
        alpha: f32,
    } {
        const i = stepInterpolation(samples, t);
        if (i == samples.len - 1) return .{ .prev_i = i, .next_i = i, .alpha = 0 };

        const d = samples[i + 1] - samples[i];
        std.debug.assert(d > 0);
        const alpha = std.math.clamp((t - samples[i]) / d, 0, 1);

        return .{ .prev_i = i, .next_i = i + 1, .alpha = alpha };
    }

    pub fn access(comptime T: type, data: []const f32, i: usize) T {
        return switch (T) {
            Vec3 => Vec3.new(data[3 * i + 0], data[3 * i + 1], data[3 * i + 2]),
            // Quat => Quat.new(data[4 * i + 3], data[4 * i + 0], data[4 * i + 1], data[4 * i + 2]),
            // Mat4 => Mat4.fromSlice(data[16 * i ..][0..16]),
            else => @compileError("unexpected type"),
        };
    }

    pub fn updateAnimation(self: *Mesh, time: f32) void {
        if (self.zmesh_data.skins == null)
            return;

        const animation = self.zmesh_data.animations.?[0];
        const animation_duration = zmesh.io.computeAnimationDuration(&animation);

        // loop animation for now!
        const t: f32 = @mod(time * 0.01, animation_duration);
        // debug.log("Animation time: {d:.2}", .{t});

        const nodes = self.zmesh_data.skins.?[0].joints;
        const nodes_count = self.zmesh_data.skins.?[0].joints_count;

        var local_transforms: [64]math.Mat4 = [_]math.Mat4{math.Mat4.identity} ** 64;

        for (0..nodes_count) |i| {
            // const node = nodes[i];
            // local_transforms[i] = math.Mat4.translate(math.Vec3.fromArray(node.translation)).mul(math.Mat4.scale(math.Vec3.fromArray(node.scale)));
            local_transforms[i] = math.Mat4.identity;
        }

        for (0..animation.channels_count) |i| {
            const channel = animation.channels[i];
            const sampler = channel.sampler;

            if (channel.target_path == .translation) {
                var node_idx: usize = 0;
                for (0..nodes_count) |ni| {
                    if (nodes[ni] == channel.target_node.?) {
                        node_idx = ni;
                        break;
                    }
                }

                const sampled = self.sampleAnimation(sampler, t);

                // debug.log("Channel {d} Sampled: {d:.2} {d:.2} {d:.2}", .{ i, sampled.x, sampled.y, sampled.z });
                local_transforms[node_idx] = local_transforms[node_idx].mul(math.Mat4.translate(sampled));
            }
        }

        // test moving a joint around to check the joint chain heirarchy
        // const test_joint_idx = @as(usize, @intFromFloat(time * 0.03)) % nodes_count;
        // local_transforms[test_joint_idx] = math.Mat4.translate(math.Vec3.new(std.math.sin(time * 0.04) * 0.1, 0.0, 0.0));

        // update each joint location based on each node in the joint heirarchy
        for (0..nodes_count) |i| {
            var node = nodes[i];
            self.joint_locations[i] = local_transforms[i];

            while (node.parent) |parent| : (node = parent) {
                var parent_idx: usize = 0;
                for (0..nodes_count) |ni| {
                    if (nodes[ni] == parent) {
                        parent_idx = ni;
                        break;
                    }
                }

                const parent_transform = local_transforms[parent_idx];
                self.joint_locations[i] = parent_transform.mul(self.joint_locations[i]);
            }
        }
    }
};

/// Create a mesh out of some vertex data
pub fn createMesh(vertices: []graphics.Vertex, indices: []u32, normals: [][3]f32, tangents: [][4]f32, material: graphics.Material) Mesh {
    // create a mesh with the default vertex layout
    return createMeshWithLayout(vertices, indices, normals, tangents, material, vertex_layout);
}

pub fn createSkinnedMesh(vertices: []graphics.Vertex, indices: []u32, normals: [][3]f32, tangents: [][4]f32, joints: [][4]f32, weights: [][4]f32, material: graphics.Material, data: *zmesh.io.zcgltf.Data) Mesh {
    // create a mesh with the default vertex layout
    // debug.log("Creating skinned mesh: {d} indices, {d} normals, {d}tangents, {d} joints, {d} weights", .{ indices.len, normals.len, tangents.len, joints.len, weights.len });

    const layout = getSkinnedVertexLayout();
    var bindings = graphics.Bindings.init(.{
        .index_len = indices.len,
        .vert_len = vertices.len,
        .vertex_layout = layout,
    });

    // for (joints) |j| {
    //     debug.log("Joint: {d:.1} {d:.1} {d:.1} {d:.1}", .{ j[0], j[1], j[2], j[3] });
    // }
    // for (weights) |j| {
    //     debug.log("Weights: {d:.1} {d:.1} {d:.1} {d:.1}", .{ j[0], j[1], j[2], j[3] });
    // }

    bindings.setWithJoints(vertices, indices, normals, tangents, joints, weights, indices.len);

    const m: Mesh = Mesh{
        .bindings = bindings,
        .material = material,
        .bounds = boundingbox.BoundingBox.initFromVerts(vertices),
        .zmesh_data = data,
    };
    return m;
}

/// Create a mesh out of some vertex data with a given vertex layout
pub fn createMeshWithLayout(vertices: []graphics.Vertex, indices: []u32, normals: [][3]f32, tangents: [][4]f32, material: graphics.Material, layout: graphics.VertexLayout) Mesh {
    debug.log("Creating mesh: {d} indices, {d} normals, {d}tangents", .{ indices.len, normals.len, tangents.len });

    var bindings = graphics.Bindings.init(.{
        .index_len = indices.len,
        .vert_len = vertices.len,
        .vertex_layout = layout,
    });

    bindings.set(vertices, indices, normals, tangents, indices.len);

    const m: Mesh = Mesh{
        .bindings = bindings,
        .material = material,
        .bounds = boundingbox.BoundingBox.initFromVerts(vertices),
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
            .{ .binding = .VERT_PACKED, .buffer_slot = 0, .item_size = @sizeOf(Vertex) },
            .{ .binding = .VERT_NORMALS, .buffer_slot = 1, .item_size = @sizeOf([3]f32) },
            .{ .binding = .VERT_TANGENTS, .buffer_slot = 2, .item_size = @sizeOf([4]f32) },
        },
    };
}

pub fn getSkinnedVertexLayout() graphics.VertexLayout {
    return graphics.VertexLayout{
        .attributes = &[_]graphics.VertexLayoutAttribute{
            .{ .binding = .VERT_PACKED, .buffer_slot = 0, .item_size = @sizeOf(Vertex) },
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
        .{ .name = "color0", .attr_type = .UBYTE4N, .binding = .VERT_PACKED },
        .{ .name = "texcoord0", .attr_type = .FLOAT2, .binding = .VERT_PACKED },
        .{ .name = "normals", .attr_type = .FLOAT3, .binding = .VERT_NORMALS },
        .{ .name = "tangents", .attr_type = .FLOAT4, .binding = .VERT_TANGENTS },
    };
}

pub fn getSkinnedShaderAttributes() []const graphics.ShaderAttribute {
    return &[_]graphics.ShaderAttribute{
        .{ .name = "pos", .attr_type = .FLOAT3, .binding = .VERT_PACKED },
        .{ .name = "color0", .attr_type = .UBYTE4N, .binding = .VERT_PACKED },
        .{ .name = "texcoord0", .attr_type = .FLOAT2, .binding = .VERT_PACKED },
        .{ .name = "normals", .attr_type = .FLOAT3, .binding = .VERT_NORMALS },
        .{ .name = "tangents", .attr_type = .FLOAT4, .binding = .VERT_TANGENTS },
        .{ .name = "joints", .attr_type = .FLOAT4, .binding = .VERT_JOINTS },
        .{ .name = "weights", .attr_type = .FLOAT4, .binding = .VERT_WEIGHTS },
    };
}

/// MeshBuildler is a helper for making runtime meshes
pub const MeshBuilder = struct {
    vertices: std.ArrayList(Vertex) = undefined,
    indices: std.ArrayList(u32) = undefined,
    normals: std.ArrayList([3]f32) = undefined,
    tangents: std.ArrayList([4]f32) = undefined,

    pub fn init(allocator: std.mem.Allocator) MeshBuilder {
        return MeshBuilder{
            .vertices = std.ArrayList(Vertex).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
            .normals = std.ArrayList([3]f32).init(allocator),
            .tangents = std.ArrayList([4]f32).init(allocator),
        };
    }

    /// Adds a quad to the mesh builder
    pub fn addQuad(self: *MeshBuilder, v0: Vec2, v1: Vec2, v2: Vec2, v3: Vec2, transform: math.Mat4, color: Color) !void {
        const u = 0.0;
        const v = 0.0;
        const u_2 = 1.0;
        const v_2 = 1.0;
        const color_i = color.toInt();

        const verts = &[_]Vertex{
            .{ .x = v0.x, .y = v0.y, .z = 0, .color = color_i, .u = u, .v = v_2 },
            .{ .x = v1.x, .y = v1.y, .z = 0, .color = color_i, .u = u_2, .v = v_2 },
            .{ .x = v2.x, .y = v2.y, .z = 0, .color = color_i, .u = u_2, .v = v },
            .{ .x = v3.x, .y = v3.y, .z = 0, .color = color_i, .u = u, .v = v },
        };

        const indices = &[_]u32{ 0, 1, 2, 0, 2, 3 };

        const v_pos = @as(u32, @intCast(self.vertices.items.len));
        for (verts) |vert| {
            try self.vertices.append(Vertex.mulMat4(vert, transform));
        }

        for (indices) |idx| {
            try self.indices.append(idx + v_pos);
        }

        // todo: add normals and tangents
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
        const color_i = color.toInt();

        const verts = &[_]Vertex{
            .{ .x = v0.x, .y = v0.y, .z = v0.z, .color = color_i, .u = u, .v = v_2 },
            .{ .x = v1.x, .y = v1.y, .z = v1.z, .color = color_i, .u = u_2, .v = v_2 },
            .{ .x = v2.x, .y = v2.y, .z = v2.z, .color = color_i, .u = u_2, .v = v },
        };

        const indices = &[_]u32{ 0, 1, 2 };

        for (verts) |vert| {
            try self.vertices.append(Vertex.mulMat4(vert, transform));
        }

        const v_pos = @as(u32, @intCast(self.indices.items.len));
        for (indices) |idx| {
            try self.indices.append(idx + v_pos);
        }
    }

    /// Adds a triangle to the mesh builder, from vertices
    pub fn addTriangleFromVertices(self: *MeshBuilder, v0: Vertex, v1: Vertex, v2: Vertex, transform: math.Mat4) !void {
        try self.vertices.append(Vertex.mulMat4(v0, transform));
        try self.vertices.append(Vertex.mulMat4(v1, transform));
        try self.vertices.append(Vertex.mulMat4(v2, transform));

        const indices = &[_]u32{ 0, 1, 2 };

        const v_pos = @as(u32, @intCast(self.indices.items.len));
        for (indices) |idx| {
            try self.indices.append(idx + v_pos);
        }
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
    pub fn buildMesh(self: *const MeshBuilder, material: graphics.Material) Mesh {
        const layout = graphics.VertexLayout{
            .attributes = &[_]graphics.VertexLayoutAttribute{
                .{ .binding = .VERT_PACKED, .buffer_slot = 0, .item_size = @sizeOf(Vertex) },
            },
        };

        return createMeshWithLayout(self.vertices.items, self.indices.items, self.normals.items, self.tangents.items, material, layout);
    }

    /// Cleans up a mesh builder
    pub fn deinit(self: *MeshBuilder) void {
        self.vertices.deinit();
        self.indices.deinit();
        self.normals.deinit();
        self.tangents.deinit();
    }
};
