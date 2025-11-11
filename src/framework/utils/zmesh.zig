const std = @import("std");
const assert = std.debug.assert;

const zmesh = @import("zmesh");
const zcgltf = zmesh.io.zcgltf;
const Data = zcgltf.Data;

// Pulled from zmesh's appendMeshPrimitive, but adding joints and weights to support skinned meshes
pub fn appendMeshPrimitive(
    allocator: std.mem.Allocator,
    data: *Data,
    mesh_index: u32,
    prim_index: u32,
    indices: *std.ArrayListUnmanaged(u32),
    positions: *std.ArrayListUnmanaged([3]f32),
    normals: ?*std.ArrayListUnmanaged([3]f32),
    texcoords0: ?*std.ArrayListUnmanaged([2]f32),
    tangents: ?*std.ArrayListUnmanaged([4]f32),
    joints: ?*std.ArrayListUnmanaged([4]f32),
    weights: ?*std.ArrayListUnmanaged([4]f32),
) !void {
    assert(mesh_index < data.meshes_count);
    assert(prim_index < data.meshes.?[mesh_index].primitives_count);

    const mesh = &data.meshes.?[mesh_index];
    const prim = &mesh.primitives[prim_index];

    const num_vertices: u32 = @as(u32, @intCast(prim.attributes[0].data.count));
    const num_indices: u32 = @as(u32, @intCast(prim.indices.?.count));

    // Indices.
    {
        try indices.ensureTotalCapacity(allocator, indices.items.len + num_indices);

        const accessor = prim.indices.?;
        const buffer_view = accessor.buffer_view.?;

        assert(accessor.stride == buffer_view.stride or buffer_view.stride == 0);
        assert(buffer_view.buffer.data != null);

        const data_addr = @as([*]const u8, @ptrCast(buffer_view.buffer.data)) +
            accessor.offset + buffer_view.offset;

        if (accessor.stride == 1) {
            if (accessor.component_type != .r_8u) {
                return error.InvalidIndicesAccessorComponentType;
            }
            const src = @as([*]const u8, @ptrCast(data_addr));
            var i: u32 = 0;
            while (i < num_indices) : (i += 1) {
                indices.appendAssumeCapacity(src[i]);
            }
        } else if (accessor.stride == 2) {
            if (accessor.component_type != .r_16u) {
                return error.InvalidIndicesAccessorComponentType;
            }
            const src = @as([*]const u16, @ptrCast(@alignCast(data_addr)));
            var i: u32 = 0;
            while (i < num_indices) : (i += 1) {
                indices.appendAssumeCapacity(src[i]);
            }
        } else if (accessor.stride == 4) {
            if (accessor.component_type != .r_32u) {
                return error.InvalidIndicesAccessorComponentType;
            }
            const src = @as([*]const u32, @ptrCast(@alignCast(data_addr)));
            var i: u32 = 0;
            while (i < num_indices) : (i += 1) {
                indices.appendAssumeCapacity(src[i]);
            }
        } else {
            return error.InvalidIndicesAccessorStride;
        }
    }

    // Attributes.
    {
        const attributes = prim.attributes[0..prim.attributes_count];
        for (attributes) |attrib| {
            const accessor = attrib.data;

            const buffer_view = accessor.buffer_view.?;
            assert(buffer_view.buffer.data != null);

            assert(accessor.stride == buffer_view.stride or buffer_view.stride == 0);
            // assert(accessor.stride * accessor.count == buffer_view.size); // CC: Original zmesh asserts don't handle joints / weights

            const data_addr = @as([*]const u8, @ptrCast(buffer_view.buffer.data)) +
                accessor.offset + buffer_view.offset;

            if (attrib.type == .position) {
                assert(accessor.component_type == .r_32f);
                assert(accessor.type == .vec3);
                const slice = @as([*]const [3]f32, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                try positions.appendSlice(allocator, slice);
            } else if (attrib.type == .normal) {
                if (normals) |n| {
                    assert(accessor.component_type == .r_32f);
                    assert(accessor.type == .vec3);
                    const slice = @as([*]const [3]f32, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                    try n.appendSlice(allocator, slice);
                }
            } else if (attrib.type == .texcoord) {
                if (texcoords0) |tc| {
                    assert(accessor.component_type == .r_32f);
                    assert(accessor.type == .vec2);
                    const slice = @as([*]const [2]f32, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                    try tc.appendSlice(allocator, slice);
                }
            } else if (attrib.type == .tangent) {
                if (tangents) |tan| {
                    assert(accessor.component_type == .r_32f);
                    assert(accessor.type == .vec4);
                    const slice = @as([*]const [4]f32, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                    try tan.appendSlice(allocator, slice);
                }
            } else if (attrib.type == .joints) {
                if (joints) |j| {
                    if (accessor.component_type == .r_8u) {
                        const slice = @as([*]const [4]u8, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                        for (slice) |v| {
                            try j.append(allocator, [4]f32{ @floatFromInt(v[0]), @floatFromInt(v[1]), @floatFromInt(v[2]), @floatFromInt(v[3]) });
                        }
                    } else if (accessor.component_type == .r_16u) {
                        const slice = @as([*]const [4]u16, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                        for (slice) |v| {
                            try j.append(allocator, [4]f32{ @floatFromInt(v[0]), @floatFromInt(v[1]), @floatFromInt(v[2]), @floatFromInt(v[3]) });
                        }
                    }
                }
            } else if (attrib.type == .weights) {
                if (weights) |w| {
                    assert(accessor.type == .vec4);
                    const slice = @as([*]const [4]f32, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                    try w.appendSlice(allocator, slice);
                }
            }
        }
    }
}

pub fn getAnimationSamplerData(accessor: *zcgltf.Accessor) []const f32 {
    const buffer_view = accessor.buffer_view.?;

    assert(buffer_view.buffer.data != null);
    assert(accessor.stride == buffer_view.stride or buffer_view.stride == 0);

    const data_addr = @as([*]const u8, @ptrCast(buffer_view.buffer.data)) + accessor.offset + buffer_view.offset;

    const slice = @as([*]const f32, @ptrCast(@alignCast(data_addr)))[0 .. accessor.count * zcgltf.Type.numComponents(accessor.type)];
    return slice;
}

pub fn computeAnimationDuration(animation: *const zcgltf.Animation) f32 {
    var duration: f32 = 0;

    for (0..animation.samplers_count, animation.samplers) |_, sampler| {
        const samples = getAnimationSamplerData(sampler.input);
        duration = @max(duration, samples[samples.len - 1]);
    }

    return duration;
}
