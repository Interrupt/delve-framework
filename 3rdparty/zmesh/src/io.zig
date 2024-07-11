const std = @import("std");
const assert = std.debug.assert;
const mem = @import("memory.zig");
pub const zcgltf = @import("zcgltf.zig");

pub fn parseAndLoadFile(pathname: [:0]const u8) zcgltf.Error!*zcgltf.Data {
    const options = zcgltf.Options{
        .memory = .{
            .alloc_func = mem.zmeshAllocUser,
            .free_func = mem.zmeshFreeUser,
        },
    };

    const data = try zcgltf.parseFile(options, pathname);
    errdefer zcgltf.free(data);

    try zcgltf.loadBuffers(options, data, pathname);

    return data;
}

pub fn freeData(data: *zcgltf.Data) void {
    zcgltf.free(data);
}

pub fn appendMeshPrimitive(
    data: *zcgltf.Data,
    mesh_index: u32,
    prim_index: u32,
    indices: *std.ArrayList(u32),
    positions: *std.ArrayList([3]f32),
    normals: ?*std.ArrayList([3]f32),
    texcoords0: ?*std.ArrayList([2]f32),
    tangents: ?*std.ArrayList([4]f32),
    joints: ?*std.ArrayList([4]f32),
    weights: ?*std.ArrayList([4]f32),
) !void {
    assert(mesh_index < data.meshes_count);
    assert(prim_index < data.meshes.?[mesh_index].primitives_count);

    const mesh = &data.meshes.?[mesh_index];
    const prim = &mesh.primitives[prim_index];

    const num_vertices: u32 = @as(u32, @intCast(prim.attributes[0].data.count));
    const num_indices: u32 = @as(u32, @intCast(prim.indices.?.count));

    const start_indices: u32 = @intCast(positions.items.len);

    // Indices.
    {
        try indices.ensureTotalCapacity(indices.items.len + num_indices);

        const accessor = prim.indices.?;
        const buffer_view = accessor.buffer_view.?;

        assert(accessor.stride == buffer_view.stride or buffer_view.stride == 0);
        // assert(accessor.stride * accessor.count == buffer_view.size);
        assert(buffer_view.buffer.data != null);

        const data_addr = @as([*]const u8, @ptrCast(buffer_view.buffer.data)) +
            accessor.offset + buffer_view.offset;

        if (accessor.stride == 1) {
            assert(accessor.component_type == .r_8u);
            const src = @as([*]const u8, @ptrCast(data_addr));
            var i: u32 = 0;
            while (i < num_indices) : (i += 1) {
                indices.appendAssumeCapacity(src[i] + start_indices);
            }
        } else if (accessor.stride == 2) {
            assert(accessor.component_type == .r_16u);
            const src = @as([*]const u16, @ptrCast(@alignCast(data_addr)));
            var i: u32 = 0;
            while (i < num_indices) : (i += 1) {
                indices.appendAssumeCapacity(src[i] + start_indices);
            }
        } else if (accessor.stride == 4) {
            assert(accessor.component_type == .r_32u);
            const src = @as([*]const u32, @ptrCast(@alignCast(data_addr)));
            var i: u32 = 0;
            while (i < num_indices) : (i += 1) {
                indices.appendAssumeCapacity(src[i] + start_indices);
            }
        } else {
            unreachable;
        }
    }

    // Attributes.
    {
        const attributes = prim.attributes[0..prim.attributes_count];
        for (attributes) |attrib| {
            const accessor = attrib.data;
            // std.debug.print("{}\n", .{attrib.type});
            // std.debug.print("{}\n", .{accessor.component_type});
            // std.debug.print("{}\n", .{accessor.type});
            // std.debug.print("{}\n", .{accessor.stride});
            // assert(accessor.component_type == .r_32f);

            const buffer_view = accessor.buffer_view.?;
            assert(buffer_view.buffer.data != null);

            assert(accessor.stride == buffer_view.stride or buffer_view.stride == 0);

            // std.debug.print("Accessor stride: {d} Accessor count: {d} Buffer View size {d}\n", .{ accessor.stride, accessor.count, buffer_view.size });
            // assert(accessor.stride * accessor.count == buffer_view.size);

            const data_addr = @as([*]const u8, @ptrCast(buffer_view.buffer.data)) +
                accessor.offset + buffer_view.offset;

            if (attrib.type == .position) {
                assert(accessor.component_type == .r_32f);
                assert(accessor.type == .vec3);
                const slice = @as([*]const [3]f32, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                try positions.appendSlice(slice);
            } else if (attrib.type == .normal) {
                if (normals) |n| {
                    assert(accessor.component_type == .r_32f);
                    assert(accessor.type == .vec3);
                    const slice = @as([*]const [3]f32, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                    try n.appendSlice(slice);
                }
            } else if (attrib.type == .texcoord) {
                if (texcoords0) |tc| {
                    assert(accessor.component_type == .r_32f);
                    assert(accessor.type == .vec2);
                    const slice = @as([*]const [2]f32, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                    try tc.appendSlice(slice);
                }
            } else if (attrib.type == .tangent) {
                if (tangents) |tan| {
                    assert(accessor.component_type == .r_32f);
                    assert(accessor.type == .vec4);
                    const slice = @as([*]const [4]f32, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                    try tan.appendSlice(slice);
                }
            } else if (attrib.type == .joints) {
                if (joints) |j| {
                    if (accessor.component_type == .r_8u) {
                        const slice = @as([*]const [4]u8, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                        for (slice) |v| {
                            try j.append([4]f32{ @floatFromInt(v[0]), @floatFromInt(v[1]), @floatFromInt(v[2]), @floatFromInt(v[3]) });
                        }
                    } else if (accessor.component_type == .r_16u) {
                        const slice = @as([*]const [4]u16, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                        for (slice) |v| {
                            try j.append([4]f32{ @floatFromInt(v[0]), @floatFromInt(v[1]), @floatFromInt(v[2]), @floatFromInt(v[3]) });
                        }
                    }
                }
            } else if (attrib.type == .weights) {
                if (weights) |w| {
                    assert(accessor.component_type == .r_32f);
                    assert(accessor.type == .vec4);
                    const slice = @as([*]const [4]f32, @ptrCast(@alignCast(data_addr)))[0..num_vertices];
                    try w.appendSlice(slice);
                }
            }
        }
    }
}

pub fn getAnimationSamplerData(accessor: *zcgltf.Accessor) []const f32 {
    const buffer_view = accessor.buffer_view.?;
    // std.debug.print("accessor type:   {}\n", .{accessor.component_type});
    // std.debug.print("accessor count:  {d}\n", .{accessor.count});
    // std.debug.print("accessor type:   {}\n", .{accessor.type});
    // std.debug.print("accessor stride: {d}\n", .{accessor.stride});

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

    // std.debug.print("Computed animation duration: {d:.2}\n", .{duration});
    return duration;
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
