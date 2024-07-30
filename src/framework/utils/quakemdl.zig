const std = @import("std");

const debug = @import("../debug.zig");
const images = @import("../images.zig");
const math = @import("../math.zig");
const mem = @import("../mem.zig");
const mesh = @import("../graphics/mesh.zig");
const graphics = @import("../platform/graphics.zig");

const Allocator = std.mem.Allocator;
const File = std.fs.File;

pub const MDL = struct {
    frames: []MDLFrameType,
    skins: []MDLSkinType
};

pub const MDLFrameTypeTag = enum {
    single,
    group
};

pub const MDLFrameType = union(MDLFrameTypeTag) {
    single: MDLFrame,
    group: MDLFrameGroup
};

pub const MDLFrame = struct {
    name: [16]u8,
    mesh: mesh.Mesh,
};

pub const MDLFrameGroup = struct {
    meshes: []mesh.Mesh,
    intervals: []f32
};

pub const MDLSkinTypeTag = enum {
    single,
    group
};

pub const MDLSkinType = union(MDLSkinTypeTag) {
    single: MDLSkin,
    group: MDLSkinGroup
};

pub const MDLSkin = struct {
    texture: graphics.Texture,
};

pub const MDLSkinGroup = struct {
    textures: []graphics.Texture,
    intervals: []f32
};

pub const MDLFileHeader = extern struct {
    magic: [4]u8,
    version: u32,
    scale: [3]f32,
    origin: [3]f32,
    radius: f32,
    offsets: [3]f32,
    skin_count: u32,
    skin_width: u32,
    skin_height: u32,
    vertex_count: u32,
    triangle_count: u32,
    frame_count: u32,
    sync_type: u32,
    flags: u32,
    size: u32,

    pub fn read(file: File) !MDLFileHeader {
        const size = @sizeOf(MDLFileHeader);
        var bytes: [size]u8 = undefined;
        _ = try file.read(&bytes);

        return @bitCast(bytes);
    }
};

pub const SkinType = enum(u32) {
    SINGLE,
    GROUP
};

pub const STVertex = extern struct {
    on_seam: u32,
    s: u32,
    t: u32
};

pub const Triangle = extern struct {
    faces_front: u32,
    indexes: [3]u32
};

pub const TriVertex = struct {
    vertex: [3]u8,
    light_index: u8
};

pub const SingleFrameStruct = extern struct {
    type: u32,
    min: [4]u8,
    max: [4]u8,
};

pub fn bytesToStructArray(comptime T: type, bytes: []u8) std.mem.Allocator.Error![]T {
    const allocator = mem.getAllocator();
    const size: u32 = @sizeOf(T);
    const length: u32 = @as(u32, @intCast(bytes.len)) / size;
    const result: []T = try allocator.alloc(T, length);

    var i: u32 = 0;
    while (i < length) : (i += 1) {
        result[i] = std.mem.bytesToValue(T, &bytes[i * size]);
    }

    return result;
}

fn make_vertex(triangle: Triangle, trivertex: TriVertex, stvertex: STVertex, skin_width: f32, skin_height: f32) graphics.Vertex {
    var vertex: graphics.Vertex = .{
        .x = @floatFromInt(trivertex.vertex[0]),
        .y = @floatFromInt(trivertex.vertex[1]),
        .z = @floatFromInt(trivertex.vertex[2]),
        .u = @as(f32, @floatFromInt(stvertex.s)) / skin_width,
        .v = @as(f32, @floatFromInt(stvertex.t)) / skin_height,
    };

    if (triangle.faces_front == 0 and stvertex.on_seam != 0) {
        vertex.u += 0.5;
    }

    return vertex;
}

pub fn get_mdl(allocator: Allocator, path: []const u8) !MDL {
    var file = try std.fs.cwd().openFile(
        path,
        std.fs.File.OpenFlags{ .mode = .read_only }
    );

    defer file.close();

    const header = try MDLFileHeader.read(file);

    const frames = try allocator.alloc(MDLFrameType, header.frame_count);
    const skins = try allocator.alloc(MDLSkinType, header.skin_count);

    var work: [4]u8 = undefined;

    // Skins

    const indexes: []u8 = try allocator.alloc(u8, header.skin_height * header.skin_width);
    defer allocator.free(indexes);

    const pixel_size = header.skin_width * header.skin_height * 4;

    for (0..header.skin_count) |i| {
        _ = try file.read(&work);
        const skin_type: SkinType = @enumFromInt(@as(u32, @bitCast(work)));

        if (skin_type == SkinType.SINGLE) {
            _ = try file.read(indexes);

            // Convert indices to RGBA
            const image_bytes = try allocator.alloc(u8, pixel_size);
            for (0.., indexes) |j, index| {
                image_bytes[(j * 4) + 0] = Palette[(@as(u32, index) * 3) + 0];
                image_bytes[(j * 4) + 1] = Palette[(@as(u32, index) * 3) + 1];
                image_bytes[(j * 4) + 2] = Palette[(@as(u32, index) * 3) + 2];
                image_bytes[(j * 4) + 3] = 255;
            }

            const texture = graphics.Texture.initFromBytes(header.skin_width, header.skin_height, image_bytes);
            skins[i] = .{ .single = .{ .texture = texture } };

        }
        else if (skin_type == SkinType.GROUP) {
            _ = try file.read(&work);
            const count: u32 = @bitCast(work);

            const intervals_buff = try allocator.alloc(u8, count * @sizeOf(f32));
            _ = try file.read(intervals_buff);
            const intervals: []f32 = try bytesToStructArray(f32, intervals_buff);

            const textures: []graphics.Texture = try allocator.alloc(graphics.Texture, count);

            for (0..count) |j| {
                _ = try file.read(indexes);

                // Convert indices to RGBA
                const image_bytes = try allocator.alloc(u8, pixel_size);
                for (0.., indexes) |k, index| {
                    image_bytes[(k * 4) + 0] = Palette[(@as(u32, index) * 3) + 0];
                    image_bytes[(k * 4) + 1] = Palette[(@as(u32, index) * 3) + 1];
                    image_bytes[(k * 4) + 2] = Palette[(@as(u32, index) * 3) + 2];
                    image_bytes[(k * 4) + 3] = 255;
                }

                textures[j] = graphics.Texture.initFromBytes(header.skin_width, header.skin_height, image_bytes);
            }

            skins[i] = .{ .group = .{ .intervals = intervals, .textures = textures } };
        }
    }

    // Material
    const default_material = graphics.Material.init(.{
        .shader = graphics.Shader.initDefault(.{}),
        .texture_0 = skins[0].single.texture,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // ST Vertexes
    const stvert_buff: []u8 = try allocator.alloc(u8, @sizeOf(STVertex) * header.vertex_count);
    defer allocator.free(stvert_buff);
    _ = try file.read(stvert_buff);
    const stvertices = try bytesToStructArray(STVertex, stvert_buff);
    defer allocator.free(stvertices);

    // Triangles
    const triangle_buff: []u8 = try allocator.alloc(u8, @sizeOf(Triangle) * header.triangle_count);
    defer allocator.free(triangle_buff);
    _ = try file.read(triangle_buff);
    const triangles = try bytesToStructArray(Triangle, triangle_buff);
    defer allocator.free(triangles);

    // Frames

    var m = math.Mat4.identity;
    m = m.mul(math.Mat4.translate(math.vec3(header.origin[0], header.origin[2], header.origin[1])));
    m = m.mul(math.Mat4.scale(math.vec3(header.scale[0], header.scale[1], header.scale[2])));

    // Swizzle Y/Z axes
    m.m[1][2] = m.m[1][1];
    m.m[1][1] = 0;
    m.m[2][1] = m.m[2][2];
    m.m[2][2] = 0;

    const sw: f32 = @floatFromInt(header.skin_width);
    const sh: f32 = @floatFromInt(header.skin_height);

    const vertbuff = try allocator.alloc(u8, @sizeOf(TriVertex) * header.vertex_count);
    defer allocator.free(vertbuff);

    for (0..header.frame_count) |i| {
        const buff: []u8 = try allocator.alloc(u8, @sizeOf(SingleFrameStruct));
        _ = try file.read(buff);
        const frame_struct = std.mem.bytesToValue(SingleFrameStruct, buff);

        if (frame_struct.type == 0) {
            const name: []u8 = try allocator.alloc(u8, 16);
            _ = try file.read(name);
            _ = try file.read(vertbuff);

            const trivertexes = try bytesToStructArray(TriVertex, vertbuff);

            var builder = mesh.MeshBuilder.init(allocator);
            defer builder.deinit();

            for (triangles) |triangle| {
                const idx0 = triangle.indexes[0];
                const idx1 = triangle.indexes[1];
                const idx2 = triangle.indexes[2];

                const tv0 = trivertexes[idx0];
                const tv1 = trivertexes[idx1];
                const tv2 = trivertexes[idx2];

                const stv0 = stvertices[idx0];
                const stv1 = stvertices[idx1];
                const stv2 = stvertices[idx2];

                const v0 = make_vertex(triangle, tv0, stv0, sw, sh);
                const v1 = make_vertex(triangle, tv1, stv1, sw, sh);
                const v2 = make_vertex(triangle, tv2, stv2, sw, sh);

                _ = try builder.addTriangleFromVertices(v0, v1, v2, m);
            }

            const frame_mesh = builder.buildMesh(default_material);

            frames[i] = .{
                .single = .{
                    .name = name[0..16].*,
                    .mesh = frame_mesh
                }
            };
        }
        else {
            _ = try file.read(&work);
            const count: u32 = @bitCast(work);

            const intervals_buff = try allocator.alloc(u8, count * @sizeOf(f32));
            _ = try file.read(intervals_buff);
            const intervals: []f32 = try bytesToStructArray(f32, intervals_buff);

            var meshes: []mesh.Mesh = try allocator.alloc(mesh.Mesh, count);

            for (0..count) |j| {
                _ = try file.read(vertbuff);

                const trivertexes = try bytesToStructArray(TriVertex, vertbuff);

                var builder = mesh.MeshBuilder.init(allocator);
                defer builder.deinit();

                for (triangles) |triangle| {
                    const idx0 = triangle.indexes[0];
                    const idx1 = triangle.indexes[1];
                    const idx2 = triangle.indexes[2];

                    const tv0 = trivertexes[idx0];
                    const tv1 = trivertexes[idx1];
                    const tv2 = trivertexes[idx2];

                    const stv0 = stvertices[idx0];
                    const stv1 = stvertices[idx1];
                    const stv2 = stvertices[idx2];

                    const v0 = make_vertex(triangle, tv0, stv0, sw, sh);
                    const v1 = make_vertex(triangle, tv1, stv1, sw, sh);
                    const v2 = make_vertex(triangle, tv2, stv2, sw, sh);

                    _ = try builder.addTriangleFromVertices(v0, v1, v2, m);
                }

                meshes[j] = builder.buildMesh(default_material);
            }

            frames[i] = .{
                .group = .{
                    .intervals = intervals,
                    .meshes = meshes
                }
            };
        }
    }

    const mdl: MDL = .{
        .frames = frames,
        .skins = skins
    };

    return mdl;
}

const Palette: [768]u8 = .{
    0x00,0x00,0x00,0x0f,0x0f,0x0f,0x1f,0x1f,0x1f,0x2f,0x2f,0x2f,
    0x3f,0x3f,0x3f,0x4b,0x4b,0x4b,0x5b,0x5b,0x5b,0x6b,0x6b,0x6b,
    0x7b,0x7b,0x7b,0x8b,0x8b,0x8b,0x9b,0x9b,0x9b,0xab,0xab,0xab,
    0xbb,0xbb,0xbb,0xcb,0xcb,0xcb,0xdb,0xdb,0xdb,0xeb,0xeb,0xeb,
    0x0f,0x0b,0x07,0x17,0x0f,0x0b,0x1f,0x17,0x0b,0x27,0x1b,0x0f,
    0x2f,0x23,0x13,0x37,0x2b,0x17,0x3f,0x2f,0x17,0x4b,0x37,0x1b,
    0x53,0x3b,0x1b,0x5b,0x43,0x1f,0x63,0x4b,0x1f,0x6b,0x53,0x1f,
    0x73,0x57,0x1f,0x7b,0x5f,0x23,0x83,0x67,0x23,0x8f,0x6f,0x23,
    0x0b,0x0b,0x0f,0x13,0x13,0x1b,0x1b,0x1b,0x27,0x27,0x27,0x33,
    0x2f,0x2f,0x3f,0x37,0x37,0x4b,0x3f,0x3f,0x57,0x47,0x47,0x67,
    0x4f,0x4f,0x73,0x5b,0x5b,0x7f,0x63,0x63,0x8b,0x6b,0x6b,0x97,
    0x73,0x73,0xa3,0x7b,0x7b,0xaf,0x83,0x83,0xbb,0x8b,0x8b,0xcb,
    0x00,0x00,0x00,0x07,0x07,0x00,0x0b,0x0b,0x00,0x13,0x13,0x00,
    0x1b,0x1b,0x00,0x23,0x23,0x00,0x2b,0x2b,0x07,0x2f,0x2f,0x07,
    0x37,0x37,0x07,0x3f,0x3f,0x07,0x47,0x47,0x07,0x4b,0x4b,0x0b,
    0x53,0x53,0x0b,0x5b,0x5b,0x0b,0x63,0x63,0x0b,0x6b,0x6b,0x0f,
    0x07,0x00,0x00,0x0f,0x00,0x00,0x17,0x00,0x00,0x1f,0x00,0x00,
    0x27,0x00,0x00,0x2f,0x00,0x00,0x37,0x00,0x00,0x3f,0x00,0x00,
    0x47,0x00,0x00,0x4f,0x00,0x00,0x57,0x00,0x00,0x5f,0x00,0x00,
    0x67,0x00,0x00,0x6f,0x00,0x00,0x77,0x00,0x00,0x7f,0x00,0x00,
    0x13,0x13,0x00,0x1b,0x1b,0x00,0x23,0x23,0x00,0x2f,0x2b,0x00,
    0x37,0x2f,0x00,0x43,0x37,0x00,0x4b,0x3b,0x07,0x57,0x43,0x07,
    0x5f,0x47,0x07,0x6b,0x4b,0x0b,0x77,0x53,0x0f,0x83,0x57,0x13,
    0x8b,0x5b,0x13,0x97,0x5f,0x1b,0xa3,0x63,0x1f,0xaf,0x67,0x23,
    0x23,0x13,0x07,0x2f,0x17,0x0b,0x3b,0x1f,0x0f,0x4b,0x23,0x13,
    0x57,0x2b,0x17,0x63,0x2f,0x1f,0x73,0x37,0x23,0x7f,0x3b,0x2b,
    0x8f,0x43,0x33,0x9f,0x4f,0x33,0xaf,0x63,0x2f,0xbf,0x77,0x2f,
    0xcf,0x8f,0x2b,0xdf,0xab,0x27,0xef,0xcb,0x1f,0xff,0xf3,0x1b,
    0x0b,0x07,0x00,0x1b,0x13,0x00,0x2b,0x23,0x0f,0x37,0x2b,0x13,
    0x47,0x33,0x1b,0x53,0x37,0x23,0x63,0x3f,0x2b,0x6f,0x47,0x33,
    0x7f,0x53,0x3f,0x8b,0x5f,0x47,0x9b,0x6b,0x53,0xa7,0x7b,0x5f,
    0xb7,0x87,0x6b,0xc3,0x93,0x7b,0xd3,0xa3,0x8b,0xe3,0xb3,0x97,
    0xab,0x8b,0xa3,0x9f,0x7f,0x97,0x93,0x73,0x87,0x8b,0x67,0x7b,
    0x7f,0x5b,0x6f,0x77,0x53,0x63,0x6b,0x4b,0x57,0x5f,0x3f,0x4b,
    0x57,0x37,0x43,0x4b,0x2f,0x37,0x43,0x27,0x2f,0x37,0x1f,0x23,
    0x2b,0x17,0x1b,0x23,0x13,0x13,0x17,0x0b,0x0b,0x0f,0x07,0x07,
    0xbb,0x73,0x9f,0xaf,0x6b,0x8f,0xa3,0x5f,0x83,0x97,0x57,0x77,
    0x8b,0x4f,0x6b,0x7f,0x4b,0x5f,0x73,0x43,0x53,0x6b,0x3b,0x4b,
    0x5f,0x33,0x3f,0x53,0x2b,0x37,0x47,0x23,0x2b,0x3b,0x1f,0x23,
    0x2f,0x17,0x1b,0x23,0x13,0x13,0x17,0x0b,0x0b,0x0f,0x07,0x07,
    0xdb,0xc3,0xbb,0xcb,0xb3,0xa7,0xbf,0xa3,0x9b,0xaf,0x97,0x8b,
    0xa3,0x87,0x7b,0x97,0x7b,0x6f,0x87,0x6f,0x5f,0x7b,0x63,0x53,
    0x6b,0x57,0x47,0x5f,0x4b,0x3b,0x53,0x3f,0x33,0x43,0x33,0x27,
    0x37,0x2b,0x1f,0x27,0x1f,0x17,0x1b,0x13,0x0f,0x0f,0x0b,0x07,
    0x6f,0x83,0x7b,0x67,0x7b,0x6f,0x5f,0x73,0x67,0x57,0x6b,0x5f,
    0x4f,0x63,0x57,0x47,0x5b,0x4f,0x3f,0x53,0x47,0x37,0x4b,0x3f,
    0x2f,0x43,0x37,0x2b,0x3b,0x2f,0x23,0x33,0x27,0x1f,0x2b,0x1f,
    0x17,0x23,0x17,0x0f,0x1b,0x13,0x0b,0x13,0x0b,0x07,0x0b,0x07,
    0xff,0xf3,0x1b,0xef,0xdf,0x17,0xdb,0xcb,0x13,0xcb,0xb7,0x0f,
    0xbb,0xa7,0x0f,0xab,0x97,0x0b,0x9b,0x83,0x07,0x8b,0x73,0x07,
    0x7b,0x63,0x07,0x6b,0x53,0x00,0x5b,0x47,0x00,0x4b,0x37,0x00,
    0x3b,0x2b,0x00,0x2b,0x1f,0x00,0x1b,0x0f,0x00,0x0b,0x07,0x00,
    0x00,0x00,0xff,0x0b,0x0b,0xef,0x13,0x13,0xdf,0x1b,0x1b,0xcf,
    0x23,0x23,0xbf,0x2b,0x2b,0xaf,0x2f,0x2f,0x9f,0x2f,0x2f,0x8f,
    0x2f,0x2f,0x7f,0x2f,0x2f,0x6f,0x2f,0x2f,0x5f,0x2b,0x2b,0x4f,
    0x23,0x23,0x3f,0x1b,0x1b,0x2f,0x13,0x13,0x1f,0x0b,0x0b,0x0f,
    0x2b,0x00,0x00,0x3b,0x00,0x00,0x4b,0x07,0x00,0x5f,0x07,0x00,
    0x6f,0x0f,0x00,0x7f,0x17,0x07,0x93,0x1f,0x07,0xa3,0x27,0x0b,
    0xb7,0x33,0x0f,0xc3,0x4b,0x1b,0xcf,0x63,0x2b,0xdb,0x7f,0x3b,
    0xe3,0x97,0x4f,0xe7,0xab,0x5f,0xef,0xbf,0x77,0xf7,0xd3,0x8b,
    0xa7,0x7b,0x3b,0xb7,0x9b,0x37,0xc7,0xc3,0x37,0xe7,0xe3,0x57,
    0x7f,0xbf,0xff,0xab,0xe7,0xff,0xd7,0xff,0xff,0x67,0x00,0x00,
    0x8b,0x00,0x00,0xb3,0x00,0x00,0xd7,0x00,0x00,0xff,0x00,0x00,
    0xff,0xf3,0x93,0xff,0xf7,0xc7,0xff,0xff,0xff,0x9f,0x5b,0x53,
};

const ANorms: [162][3]f32 = .{
    .{-0.525731, 0.000000, 0.850651},
    .{-0.442863, 0.238856, 0.864188},
    .{-0.295242, 0.000000, 0.955423},
    .{-0.309017, 0.500000, 0.809017},
    .{-0.162460, 0.262866, 0.951056},
    .{0.000000, 0.000000, 1.000000},
    .{0.000000, 0.850651, 0.525731},
    .{-0.147621, 0.716567, 0.681718},
    .{0.147621, 0.716567, 0.681718},
    .{0.000000, 0.525731, 0.850651},
    .{0.309017, 0.500000, 0.809017},
    .{0.525731, 0.000000, 0.850651},
    .{0.295242, 0.000000, 0.955423},
    .{0.442863, 0.238856, 0.864188},
    .{0.162460, 0.262866, 0.951056},
    .{-0.681718, 0.147621, 0.716567},
    .{-0.809017, 0.309017, 0.500000},
    .{-0.587785, 0.425325, 0.688191},
    .{-0.850651, 0.525731, 0.000000},
    .{-0.864188, 0.442863, 0.238856},
    .{-0.716567, 0.681718, 0.147621},
    .{-0.688191, 0.587785, 0.425325},
    .{-0.500000, 0.809017, 0.309017},
    .{-0.238856, 0.864188, 0.442863},
    .{-0.425325, 0.688191, 0.587785},
    .{-0.716567, 0.681718, -0.147621},
    .{-0.500000, 0.809017, -0.309017},
    .{-0.525731, 0.850651, 0.000000},
    .{0.000000, 0.850651, -0.525731},
    .{-0.238856, 0.864188, -0.442863},
    .{0.000000, 0.955423, -0.295242},
    .{-0.262866, 0.951056, -0.162460},
    .{0.000000, 1.000000, 0.000000},
    .{0.000000, 0.955423, 0.295242},
    .{-0.262866, 0.951056, 0.162460},
    .{0.238856, 0.864188, 0.442863},
    .{0.262866, 0.951056, 0.162460},
    .{0.500000, 0.809017, 0.309017},
    .{0.238856, 0.864188, -0.442863},
    .{0.262866, 0.951056, -0.162460},
    .{0.500000, 0.809017, -0.309017},
    .{0.850651, 0.525731, 0.000000},
    .{0.716567, 0.681718, 0.147621},
    .{0.716567, 0.681718, -0.147621},
    .{0.525731, 0.850651, 0.000000},
    .{0.425325, 0.688191, 0.587785},
    .{0.864188, 0.442863, 0.238856},
    .{0.688191, 0.587785, 0.425325},
    .{0.809017, 0.309017, 0.500000},
    .{0.681718, 0.147621, 0.716567},
    .{0.587785, 0.425325, 0.688191},
    .{0.955423, 0.295242, 0.000000},
    .{1.000000, 0.000000, 0.000000},
    .{0.951056, 0.162460, 0.262866},
    .{0.850651, -0.525731, 0.000000},
    .{0.955423, -0.295242, 0.000000},
    .{0.864188, -0.442863, 0.238856},
    .{0.951056, -0.162460, 0.262866},
    .{0.809017, -0.309017, 0.500000},
    .{0.681718, -0.147621, 0.716567},
    .{0.850651, 0.000000, 0.525731},
    .{0.864188, 0.442863, -0.238856},
    .{0.809017, 0.309017, -0.500000},
    .{0.951056, 0.162460, -0.262866},
    .{0.525731, 0.000000, -0.850651},
    .{0.681718, 0.147621, -0.716567},
    .{0.681718, -0.147621, -0.716567},
    .{0.850651, 0.000000, -0.525731},
    .{0.809017, -0.309017, -0.500000},
    .{0.864188, -0.442863, -0.238856},
    .{0.951056, -0.162460, -0.262866},
    .{0.147621, 0.716567, -0.681718},
    .{0.309017, 0.500000, -0.809017},
    .{0.425325, 0.688191, -0.587785},
    .{0.442863, 0.238856, -0.864188},
    .{0.587785, 0.425325, -0.688191},
    .{0.688191, 0.587785, -0.425325},
    .{-0.147621, 0.716567, -0.681718},
    .{-0.309017, 0.500000, -0.809017},
    .{0.000000, 0.525731, -0.850651},
    .{-0.525731, 0.000000, -0.850651},
    .{-0.442863, 0.238856, -0.864188},
    .{-0.295242, 0.000000, -0.955423},
    .{-0.162460, 0.262866, -0.951056},
    .{0.000000, 0.000000, -1.000000},
    .{0.295242, 0.000000, -0.955423},
    .{0.162460, 0.262866, -0.951056},
    .{-0.442863, -0.238856, -0.864188},
    .{-0.309017, -0.500000, -0.809017},
    .{-0.162460, -0.262866, -0.951056},
    .{0.000000, -0.850651, -0.525731},
    .{-0.147621, -0.716567, -0.681718},
    .{0.147621, -0.716567, -0.681718},
    .{0.000000, -0.525731, -0.850651},
    .{0.309017, -0.500000, -0.809017},
    .{0.442863, -0.238856, -0.864188},
    .{0.162460, -0.262866, -0.951056},
    .{0.238856, -0.864188, -0.442863},
    .{0.500000, -0.809017, -0.309017},
    .{0.425325, -0.688191, -0.587785},
    .{0.716567, -0.681718, -0.147621},
    .{0.688191, -0.587785, -0.425325},
    .{0.587785, -0.425325, -0.688191},
    .{0.000000, -0.955423, -0.295242},
    .{0.000000, -1.000000, 0.000000},
    .{0.262866, -0.951056, -0.162460},
    .{0.000000, -0.850651, 0.525731},
    .{0.000000, -0.955423, 0.295242},
    .{0.238856, -0.864188, 0.442863},
    .{0.262866, -0.951056, 0.162460},
    .{0.500000, -0.809017, 0.309017},
    .{0.716567, -0.681718, 0.147621},
    .{0.525731, -0.850651, 0.000000},
    .{-0.238856, -0.864188, -0.442863},
    .{-0.500000, -0.809017, -0.309017},
    .{-0.262866, -0.951056, -0.162460},
    .{-0.850651, -0.525731, 0.000000},
    .{-0.716567, -0.681718, -0.147621},
    .{-0.716567, -0.681718, 0.147621},
    .{-0.525731, -0.850651, 0.000000},
    .{-0.500000, -0.809017, 0.309017},
    .{-0.238856, -0.864188, 0.442863},
    .{-0.262866, -0.951056, 0.162460},
    .{-0.864188, -0.442863, 0.238856},
    .{-0.809017, -0.309017, 0.500000},
    .{-0.688191, -0.587785, 0.425325},
    .{-0.681718, -0.147621, 0.716567},
    .{-0.442863, -0.238856, 0.864188},
    .{-0.587785, -0.425325, 0.688191},
    .{-0.309017, -0.500000, 0.809017},
    .{-0.147621, -0.716567, 0.681718},
    .{-0.425325, -0.688191, 0.587785},
    .{-0.162460, -0.262866, 0.951056},
    .{0.442863, -0.238856, 0.864188},
    .{0.162460, -0.262866, 0.951056},
    .{0.309017, -0.500000, 0.809017},
    .{0.147621, -0.716567, 0.681718},
    .{0.000000, -0.525731, 0.850651},
    .{0.425325, -0.688191, 0.587785},
    .{0.587785, -0.425325, 0.688191},
    .{0.688191, -0.587785, 0.425325},
    .{-0.955423, 0.295242, 0.000000},
    .{-0.951056, 0.162460, 0.262866},
    .{-1.000000, 0.000000, 0.000000},
    .{-0.850651, 0.000000, 0.525731},
    .{-0.955423, -0.295242, 0.000000},
    .{-0.951056, -0.162460, 0.262866},
    .{-0.864188, 0.442863, -0.238856},
    .{-0.951056, 0.162460, -0.262866},
    .{-0.809017, 0.309017, -0.500000},
    .{-0.864188, -0.442863, -0.238856},
    .{-0.951056, -0.162460, -0.262866},
    .{-0.809017, -0.309017, -0.500000},
    .{-0.681718, 0.147621, -0.716567},
    .{-0.681718, -0.147621, -0.716567},
    .{-0.850651, 0.000000, -0.525731},
    .{-0.688191, 0.587785, -0.425325},
    .{-0.587785, 0.425325, -0.688191},
    .{-0.425325, 0.688191, -0.587785},
    .{-0.425325, -0.688191, -0.587785},
    .{-0.587785, -0.425325, -0.688191},
    .{-0.688191, -0.587785, -0.425325},
};
