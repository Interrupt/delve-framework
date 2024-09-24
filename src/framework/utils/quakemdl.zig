const std = @import("std");

const colors = @import("../colors.zig");
const debug = @import("../debug.zig");
const default_mesh = @import("../graphics/shaders/default-mesh.glsl.zig");
const images = @import("../images.zig");
const math = @import("../math.zig");
const mem = @import("../mem.zig");
const mesh = @import("../graphics/mesh.zig");
const graphics = @import("../platform/graphics.zig");

const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const File = std.fs.File;

pub const MDL = struct {
    frames: []MDLFrameType,
    skins: []MDLSkinType,
    material: graphics.Material,
    arena_allocator: ArenaAllocator,

    pub fn deinit(self: *MDL) void {
        for (self.skins) |skin| {
            switch (skin) {
                .single => |*frame| {
                    // self.allocator.free(frame.pixels);
                    @constCast(&frame.texture).destroy();
                },
                .group => |group| {
                    for (group.textures) |tex| {
                        @constCast(&tex).destroy();
                    }
                    // self.allocator.free(group.frames);
                },
            }
        }

        self.arena_allocator.deinit();
        self.material.deinit();
    }
};

pub const MDLFrameTypeTag = enum {
    single,
    group,
};

pub const MDLFrameType = union(MDLFrameTypeTag) {
    single: MDLFrame,
    group: MDLFrameGroup,
};

pub const MDLFrame = struct {
    name: [16]u8,
    mesh: mesh.Mesh,
};

pub const MDLFrameGroup = struct {
    frames: []MDLFrame,
    intervals: []f32,
};

pub const MDLSkinTypeTag = enum {
    single,
    group,
};

pub const MDLSkinType = union(MDLSkinTypeTag) {
    single: MDLSkin,
    group: MDLSkinGroup,
};

pub const MDLSkin = struct {
    texture: graphics.Texture,
};

pub const MDLSkinGroup = struct {
    textures: []graphics.Texture,
    intervals: []f32,
};

const MDLFileHeader_ = extern struct {
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

    pub fn read(file: File) !MDLFileHeader_ {
        const size = @sizeOf(MDLFileHeader_);
        var bytes: [size]u8 = undefined;
        _ = try file.read(&bytes);

        return @bitCast(bytes);
    }
};

const MDLMeshBuildConfig_ = struct {
    stvertexes: []STVertex_,
    triangles: []Triangle_,
    skin_width: f32,
    skin_height: f32,
    transform: math.Mat4,
    material: graphics.Material,
};

const MDLSkin_ = struct {
    type: u32,
    width: u32,
    height: u32,
    pixels: []u8,

    pub fn read(allocator: Allocator, file: File, width: u32, height: u32) !MDLSkin_ {
        // Skin type
        var bytes: [4]u8 = undefined;
        _ = try file.read(&bytes);
        const skin_type: u32 = @bitCast(bytes);
        assert(skin_type == 0);

        // Skin pixels
        const size: u32 = width * height;
        const pixels: []u8 = try allocator.alloc(u8, size);
        _ = try file.read(pixels);
        //defer allocator.free(indexes);

        return .{
            .type = skin_type,
            .width = width,
            .height = height,
            .pixels = pixels,
        };
    }

    pub fn toTexture(self: *const MDLSkin_, allocator: Allocator) !graphics.Texture {
        const size: u32 = self.width * self.height;
        const bytes = try allocator.alloc(u8, size * 4);
        defer allocator.free(bytes);

        for (0.., self.pixels) |j, index| {
            const i = @as(u32, index);
            bytes[(j * 4) + 0] = palette[(i * 3) + 0];
            bytes[(j * 4) + 1] = palette[(i * 3) + 1];
            bytes[(j * 4) + 2] = palette[(i * 3) + 2];
            bytes[(j * 4) + 3] = 255;
        }

        return graphics.Texture.initFromBytes(self.width, self.height, bytes);
    }
};

const MDLSkinGroup_ = struct {
    type: u32,
    width: u32,
    height: u32,
    count: u32,
    intervals: []f32,
    pixels: []u8,
    allocator: Allocator,

    pub fn read(allocator: Allocator, file: File, width: u32, height: u32) !MDLSkinGroup_ {
        // Skin type
        var bytes: [4]u8 = undefined;
        _ = try file.read(&bytes);
        const skin_type: u32 = @bitCast(bytes);
        assert(skin_type != 0);

        // Skin count
        _ = try file.read(&bytes);
        const count: u32 = @bitCast(bytes);

        // Skin intervals
        const intervals_buff = try allocator.alloc(u8, count * @sizeOf(f32));
        _ = try file.read(intervals_buff);
        const intervals: []f32 = try bytesToStructArray(f32, allocator, intervals_buff);

        // Skin pixels
        const size: u32 = width * height * count;
        const pixels: []u8 = try allocator.alloc(u8, size);
        _ = try file.read(pixels);

        return .{
            .type = skin_type,
            .width = width,
            .height = height,
            .count = count,
            .intervals = intervals,
            .pixels = pixels,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MDLSkinGroup_) void {
        self.allocator.free(self.intervals);
        self.allocator.free(self.pixels);
    }

    pub fn toTexture(self: *const MDLSkinGroup_, allocator: Allocator, index: u32) !graphics.Texture {
        const size: u32 = self.width * self.height;
        const bytes = try allocator.alloc(u8, size * 4);
        defer allocator.free(bytes);

        const start = index * size;
        const end = start + size;
        const pixels = self.pixels[start..end];

        for (0.., pixels) |j, index_| {
            const i = @as(u32, index_);
            bytes[(j * 4) + 0] = palette[(i * 3) + 0];
            bytes[(j * 4) + 1] = palette[(i * 3) + 1];
            bytes[(j * 4) + 2] = palette[(i * 3) + 2];
            bytes[(j * 4) + 3] = 255;
        }

        return graphics.Texture.initFromBytes(
            self.width,
            self.height,
            bytes,
        );
    }
};

const MDLFrame_ = struct {
    min: TriVertex_,
    max: TriVertex_,
    name: [16]u8,
    vertexes: []TriVertex_,

    pub fn read(allocator: Allocator, file: File, vertex_count: u32) !MDLFrame_ {
        // Frame bounds
        const min = try TriVertex_.read(file);
        const max = try TriVertex_.read(file);

        // Frame name
        const name: []u8 = try allocator.alloc(u8, 16);
        _ = try file.read(name);

        // Frame vertices
        const vertbuff = try allocator.alloc(u8, @sizeOf(TriVertex_) * vertex_count);
        defer allocator.free(vertbuff);
        _ = try file.read(vertbuff);
        const trivertexes = try bytesToStructArray(TriVertex_, allocator, vertbuff);

        return .{
            .min = min,
            .max = max,
            .name = name[0..16].*,
            .vertexes = trivertexes,
        };
    }
};

const MDLFrameGroup_ = struct {
    min: TriVertex_,
    max: TriVertex_,
    count: u32,
    intervals: []f32,
    frames: []MDLFrame_,

    pub fn read(allocator: Allocator, file: File, vertex_count: u32) !MDLFrameGroup_ {
        // Frame count
        var bytes: [4]u8 = undefined;
        _ = try file.read(&bytes);
        const count: u32 = @bitCast(bytes);

        // Frame bounds
        const min = try TriVertex_.read(file);
        const max = try TriVertex_.read(file);

        debug.log("DEBUG: {}", .{min});

        // Frame intervals
        const intervals_buff = try allocator.alloc(u8, count * @sizeOf(f32));
        _ = try file.read(intervals_buff);
        const intervals: []f32 = try bytesToStructArray(f32, allocator, intervals_buff);

        // Frames
        const frames: []MDLFrame_ = try allocator.alloc(MDLFrame_, count);
        for (0..count) |i| {
            frames[i] = try MDLFrame_.read(allocator, file, vertex_count);
        }

        return .{
            .min = min,
            .max = max,
            .count = count,
            .intervals = intervals,
            .frames = frames,
        };
    }
};

const SkinType = enum(u32) {
    SINGLE,
    GROUP,
};

const STVertex_ = extern struct {
    on_seam: u32,
    s: u32,
    t: u32,
};

const Triangle_ = extern struct {
    faces_front: u32,
    indexes: [3]u32,
};

const TriVertex_ = struct {
    vertex: [3]u8,
    light_index: u8,

    pub fn read(file: File) !TriVertex_ {
        var bytes: [4]u8 = undefined;
        _ = try file.read(&bytes);

        return .{
            .vertex = bytes[0..3].*,
            .light_index = bytes[3],
        };
    }
};

fn bytesToStructArray(comptime T: type, allocator: Allocator, bytes: []u8) std.mem.Allocator.Error![]T {
    const size: u32 = @sizeOf(T);
    const length: u32 = @as(u32, @intCast(bytes.len)) / size;
    const result: []T = try allocator.alloc(T, length);

    var i: u32 = 0;
    while (i < length) : (i += 1) {
        result[i] = std.mem.bytesToValue(T, &bytes[i * size]);
    }

    return result;
}

fn peek(file: File, buff: []u8) ![]u8 {
    const offset = try file.getPos();
    _ = try file.read(buff);
    _ = try file.seekTo(offset);

    return buff;
}

fn getNormal(index: u8) math.Vec3 {
    const n = anorms[index];
    return math.Vec3.new(n[0], n[1], n[2]);
}

fn makeVertex(triangle: Triangle_, trivertex: TriVertex_, stvertex: STVertex_, skin_width: f32, skin_height: f32) graphics.Vertex {
    var vertex: graphics.Vertex = .{
        .pos = .{
            .x = @floatFromInt(trivertex.vertex[0]),
            .y = @floatFromInt(trivertex.vertex[1]),
            .z = @floatFromInt(trivertex.vertex[2]),
        },
        .uv = .{
            .x = @as(f32, @floatFromInt(stvertex.s)) / skin_width,
            .y = @as(f32, @floatFromInt(stvertex.t)) / skin_height,
        },
        .normal = getNormal(trivertex.light_index),
        .color = colors.white,
        .tangent = math.Vec4.zero,
    };
    if (triangle.faces_front == 0 and stvertex.on_seam != 0) {
        vertex.uv.x += 0.5;
    }

    return vertex;
}

fn makeTriangle(triangle: Triangle_, frame: MDLFrame_, config: MDLMeshBuildConfig_) [3]graphics.Vertex {
    const stvertices = config.stvertexes;
    const sw = config.skin_width;
    const sh = config.skin_height;

    const idx0 = triangle.indexes[0];
    const idx1 = triangle.indexes[1];
    const idx2 = triangle.indexes[2];

    const tv0 = frame.vertexes[idx0];
    const tv1 = frame.vertexes[idx1];
    const tv2 = frame.vertexes[idx2];

    const stv0 = stvertices[idx0];
    const stv1 = stvertices[idx1];
    const stv2 = stvertices[idx2];

    const v0 = makeVertex(triangle, tv0, stv0, sw, sh);
    const v1 = makeVertex(triangle, tv1, stv1, sw, sh);
    const v2 = makeVertex(triangle, tv2, stv2, sw, sh);

    return .{ v0, v1, v2 };
}

fn makeMesh(allocator: Allocator, frame: MDLFrame_, config: MDLMeshBuildConfig_) !mesh.Mesh {
    var builder = mesh.MeshBuilder.init(allocator);
    defer builder.deinit();

    for (config.triangles) |triangle| {
        const v = makeTriangle(triangle, frame, config);
        _ = try builder.addTriangleFromVerticesWithTransform(v[0], v[1], v[2], config.transform);
    }

    return builder.buildMesh(config.material);
}

pub fn open(in_allocator: Allocator, path: []const u8) !MDL {
    var arena = ArenaAllocator.init(in_allocator);
    var allocator = arena.allocator();

    var file = try std.fs.cwd().openFile(
        path,
        std.fs.File.OpenFlags{
            .mode = .read_only,
        },
    );

    defer file.close();

    const header = try MDLFileHeader_.read(file);
    assert(header.version == 6);

    const frames = try allocator.alloc(MDLFrameType, header.frame_count);
    const skins = try allocator.alloc(MDLSkinType, header.skin_count);

    var work: [4]u8 = undefined;

    // Skins
    for (0..header.skin_count) |i| {
        _ = try peek(file, &work);
        const skin_type: SkinType = @enumFromInt(@as(u32, @bitCast(work)));

        if (skin_type == SkinType.SINGLE) {
            var skin = try MDLSkin_.read(allocator, file, header.skin_width, header.skin_height);
            const texture = try skin.toTexture(allocator);
            skins[i] = .{ .single = .{ .texture = texture } };
            defer allocator.free(skin.pixels);
        } else if (skin_type == SkinType.GROUP) {
            const group = try MDLSkinGroup_.read(allocator, file, header.skin_width, header.skin_height);

            const textures: []graphics.Texture = try allocator.alloc(graphics.Texture, group.count);
            for (0..group.count) |j| {
                textures[j] = try group.toTexture(allocator, @as(u32, @intCast(j)));
            }

            skins[i] = .{
                .group = .{
                    .intervals = group.intervals,
                    .textures = textures,
                },
            };
        }
    }

    // Material
    const default_material = try graphics.Material.init(.{
        .shader = try graphics.Shader.initFromBuiltin(.{ .vertex_attributes = mesh.getShaderAttributes() }, default_mesh),
        .own_shader = true,
        .texture_0 = skins[0].single.texture,
        .samplers = &[_]graphics.FilterMode{.NEAREST},
    });

    // ST Vertexes
    const stvert_buff: []u8 = try allocator.alloc(u8, @sizeOf(STVertex_) * header.vertex_count);
    defer allocator.free(stvert_buff);
    _ = try file.read(stvert_buff);
    const stvertices = try bytesToStructArray(STVertex_, allocator, stvert_buff);
    defer allocator.free(stvertices);

    // Triangles
    const triangle_buff: []u8 = try allocator.alloc(u8, @sizeOf(Triangle_) * header.triangle_count);
    defer allocator.free(triangle_buff);
    _ = try file.read(triangle_buff);
    const triangles = try bytesToStructArray(Triangle_, allocator, triangle_buff);
    defer allocator.free(triangles);

    // Transform
    var m = math.Mat4.identity;
    m = m.mul(math.Mat4.translate(math.vec3(header.origin[0], header.origin[2], header.origin[1])));
    m = m.mul(math.Mat4.scale(math.vec3(header.scale[0], header.scale[1], header.scale[2])));

    // Swizzle Y/Z axes
    m.m[1][2] = m.m[1][1];
    m.m[1][1] = 0;
    m.m[2][1] = m.m[2][2];
    m.m[2][2] = 0;

    const config: MDLMeshBuildConfig_ = .{
        .skin_width = @floatFromInt(header.skin_width),
        .skin_height = @floatFromInt(header.skin_height),
        .stvertexes = stvertices,
        .triangles = triangles,
        .transform = m,
        .material = default_material,
    };

    // Frames
    for (0..header.frame_count) |i| {
        _ = try file.read(&work);
        const frame_type: u32 = @bitCast(work);

        if (frame_type == 0) {
            const frame = try MDLFrame_.read(allocator, file, header.vertex_count);
            const frame_mesh = try makeMesh(allocator, frame, config);

            frames[i] = .{
                .single = .{
                    .name = frame.name[0..16].*,
                    .mesh = frame_mesh,
                },
            };
        } else {
            const group = try MDLFrameGroup_.read(allocator, file, header.vertex_count);

            const group_frames: []MDLFrame = try allocator.alloc(MDLFrame, group.count);
            for (0.., group.frames) |j, frame| {
                const group_mesh = try makeMesh(allocator, frame, config);

                group_frames[j] = .{
                    .name = frame.name[0..16].*,
                    .mesh = group_mesh,
                };
            }

            frames[i] = .{
                .group = .{
                    .intervals = group.intervals,
                    .frames = group_frames,
                },
            };
        }
    }

    const mdl: MDL = .{
        .frames = frames,
        .skins = skins,
        .material = default_material,
        .arena_allocator = arena,
    };

    return mdl;
}

const palette: [768]u8 = .{
    0x00, 0x00, 0x00, 0x0f, 0x0f, 0x0f, 0x1f, 0x1f, 0x1f, 0x2f, 0x2f, 0x2f,
    0x3f, 0x3f, 0x3f, 0x4b, 0x4b, 0x4b, 0x5b, 0x5b, 0x5b, 0x6b, 0x6b, 0x6b,
    0x7b, 0x7b, 0x7b, 0x8b, 0x8b, 0x8b, 0x9b, 0x9b, 0x9b, 0xab, 0xab, 0xab,
    0xbb, 0xbb, 0xbb, 0xcb, 0xcb, 0xcb, 0xdb, 0xdb, 0xdb, 0xeb, 0xeb, 0xeb,
    0x0f, 0x0b, 0x07, 0x17, 0x0f, 0x0b, 0x1f, 0x17, 0x0b, 0x27, 0x1b, 0x0f,
    0x2f, 0x23, 0x13, 0x37, 0x2b, 0x17, 0x3f, 0x2f, 0x17, 0x4b, 0x37, 0x1b,
    0x53, 0x3b, 0x1b, 0x5b, 0x43, 0x1f, 0x63, 0x4b, 0x1f, 0x6b, 0x53, 0x1f,
    0x73, 0x57, 0x1f, 0x7b, 0x5f, 0x23, 0x83, 0x67, 0x23, 0x8f, 0x6f, 0x23,
    0x0b, 0x0b, 0x0f, 0x13, 0x13, 0x1b, 0x1b, 0x1b, 0x27, 0x27, 0x27, 0x33,
    0x2f, 0x2f, 0x3f, 0x37, 0x37, 0x4b, 0x3f, 0x3f, 0x57, 0x47, 0x47, 0x67,
    0x4f, 0x4f, 0x73, 0x5b, 0x5b, 0x7f, 0x63, 0x63, 0x8b, 0x6b, 0x6b, 0x97,
    0x73, 0x73, 0xa3, 0x7b, 0x7b, 0xaf, 0x83, 0x83, 0xbb, 0x8b, 0x8b, 0xcb,
    0x00, 0x00, 0x00, 0x07, 0x07, 0x00, 0x0b, 0x0b, 0x00, 0x13, 0x13, 0x00,
    0x1b, 0x1b, 0x00, 0x23, 0x23, 0x00, 0x2b, 0x2b, 0x07, 0x2f, 0x2f, 0x07,
    0x37, 0x37, 0x07, 0x3f, 0x3f, 0x07, 0x47, 0x47, 0x07, 0x4b, 0x4b, 0x0b,
    0x53, 0x53, 0x0b, 0x5b, 0x5b, 0x0b, 0x63, 0x63, 0x0b, 0x6b, 0x6b, 0x0f,
    0x07, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x17, 0x00, 0x00, 0x1f, 0x00, 0x00,
    0x27, 0x00, 0x00, 0x2f, 0x00, 0x00, 0x37, 0x00, 0x00, 0x3f, 0x00, 0x00,
    0x47, 0x00, 0x00, 0x4f, 0x00, 0x00, 0x57, 0x00, 0x00, 0x5f, 0x00, 0x00,
    0x67, 0x00, 0x00, 0x6f, 0x00, 0x00, 0x77, 0x00, 0x00, 0x7f, 0x00, 0x00,
    0x13, 0x13, 0x00, 0x1b, 0x1b, 0x00, 0x23, 0x23, 0x00, 0x2f, 0x2b, 0x00,
    0x37, 0x2f, 0x00, 0x43, 0x37, 0x00, 0x4b, 0x3b, 0x07, 0x57, 0x43, 0x07,
    0x5f, 0x47, 0x07, 0x6b, 0x4b, 0x0b, 0x77, 0x53, 0x0f, 0x83, 0x57, 0x13,
    0x8b, 0x5b, 0x13, 0x97, 0x5f, 0x1b, 0xa3, 0x63, 0x1f, 0xaf, 0x67, 0x23,
    0x23, 0x13, 0x07, 0x2f, 0x17, 0x0b, 0x3b, 0x1f, 0x0f, 0x4b, 0x23, 0x13,
    0x57, 0x2b, 0x17, 0x63, 0x2f, 0x1f, 0x73, 0x37, 0x23, 0x7f, 0x3b, 0x2b,
    0x8f, 0x43, 0x33, 0x9f, 0x4f, 0x33, 0xaf, 0x63, 0x2f, 0xbf, 0x77, 0x2f,
    0xcf, 0x8f, 0x2b, 0xdf, 0xab, 0x27, 0xef, 0xcb, 0x1f, 0xff, 0xf3, 0x1b,
    0x0b, 0x07, 0x00, 0x1b, 0x13, 0x00, 0x2b, 0x23, 0x0f, 0x37, 0x2b, 0x13,
    0x47, 0x33, 0x1b, 0x53, 0x37, 0x23, 0x63, 0x3f, 0x2b, 0x6f, 0x47, 0x33,
    0x7f, 0x53, 0x3f, 0x8b, 0x5f, 0x47, 0x9b, 0x6b, 0x53, 0xa7, 0x7b, 0x5f,
    0xb7, 0x87, 0x6b, 0xc3, 0x93, 0x7b, 0xd3, 0xa3, 0x8b, 0xe3, 0xb3, 0x97,
    0xab, 0x8b, 0xa3, 0x9f, 0x7f, 0x97, 0x93, 0x73, 0x87, 0x8b, 0x67, 0x7b,
    0x7f, 0x5b, 0x6f, 0x77, 0x53, 0x63, 0x6b, 0x4b, 0x57, 0x5f, 0x3f, 0x4b,
    0x57, 0x37, 0x43, 0x4b, 0x2f, 0x37, 0x43, 0x27, 0x2f, 0x37, 0x1f, 0x23,
    0x2b, 0x17, 0x1b, 0x23, 0x13, 0x13, 0x17, 0x0b, 0x0b, 0x0f, 0x07, 0x07,
    0xbb, 0x73, 0x9f, 0xaf, 0x6b, 0x8f, 0xa3, 0x5f, 0x83, 0x97, 0x57, 0x77,
    0x8b, 0x4f, 0x6b, 0x7f, 0x4b, 0x5f, 0x73, 0x43, 0x53, 0x6b, 0x3b, 0x4b,
    0x5f, 0x33, 0x3f, 0x53, 0x2b, 0x37, 0x47, 0x23, 0x2b, 0x3b, 0x1f, 0x23,
    0x2f, 0x17, 0x1b, 0x23, 0x13, 0x13, 0x17, 0x0b, 0x0b, 0x0f, 0x07, 0x07,
    0xdb, 0xc3, 0xbb, 0xcb, 0xb3, 0xa7, 0xbf, 0xa3, 0x9b, 0xaf, 0x97, 0x8b,
    0xa3, 0x87, 0x7b, 0x97, 0x7b, 0x6f, 0x87, 0x6f, 0x5f, 0x7b, 0x63, 0x53,
    0x6b, 0x57, 0x47, 0x5f, 0x4b, 0x3b, 0x53, 0x3f, 0x33, 0x43, 0x33, 0x27,
    0x37, 0x2b, 0x1f, 0x27, 0x1f, 0x17, 0x1b, 0x13, 0x0f, 0x0f, 0x0b, 0x07,
    0x6f, 0x83, 0x7b, 0x67, 0x7b, 0x6f, 0x5f, 0x73, 0x67, 0x57, 0x6b, 0x5f,
    0x4f, 0x63, 0x57, 0x47, 0x5b, 0x4f, 0x3f, 0x53, 0x47, 0x37, 0x4b, 0x3f,
    0x2f, 0x43, 0x37, 0x2b, 0x3b, 0x2f, 0x23, 0x33, 0x27, 0x1f, 0x2b, 0x1f,
    0x17, 0x23, 0x17, 0x0f, 0x1b, 0x13, 0x0b, 0x13, 0x0b, 0x07, 0x0b, 0x07,
    0xff, 0xf3, 0x1b, 0xef, 0xdf, 0x17, 0xdb, 0xcb, 0x13, 0xcb, 0xb7, 0x0f,
    0xbb, 0xa7, 0x0f, 0xab, 0x97, 0x0b, 0x9b, 0x83, 0x07, 0x8b, 0x73, 0x07,
    0x7b, 0x63, 0x07, 0x6b, 0x53, 0x00, 0x5b, 0x47, 0x00, 0x4b, 0x37, 0x00,
    0x3b, 0x2b, 0x00, 0x2b, 0x1f, 0x00, 0x1b, 0x0f, 0x00, 0x0b, 0x07, 0x00,
    0x00, 0x00, 0xff, 0x0b, 0x0b, 0xef, 0x13, 0x13, 0xdf, 0x1b, 0x1b, 0xcf,
    0x23, 0x23, 0xbf, 0x2b, 0x2b, 0xaf, 0x2f, 0x2f, 0x9f, 0x2f, 0x2f, 0x8f,
    0x2f, 0x2f, 0x7f, 0x2f, 0x2f, 0x6f, 0x2f, 0x2f, 0x5f, 0x2b, 0x2b, 0x4f,
    0x23, 0x23, 0x3f, 0x1b, 0x1b, 0x2f, 0x13, 0x13, 0x1f, 0x0b, 0x0b, 0x0f,
    0x2b, 0x00, 0x00, 0x3b, 0x00, 0x00, 0x4b, 0x07, 0x00, 0x5f, 0x07, 0x00,
    0x6f, 0x0f, 0x00, 0x7f, 0x17, 0x07, 0x93, 0x1f, 0x07, 0xa3, 0x27, 0x0b,
    0xb7, 0x33, 0x0f, 0xc3, 0x4b, 0x1b, 0xcf, 0x63, 0x2b, 0xdb, 0x7f, 0x3b,
    0xe3, 0x97, 0x4f, 0xe7, 0xab, 0x5f, 0xef, 0xbf, 0x77, 0xf7, 0xd3, 0x8b,
    0xa7, 0x7b, 0x3b, 0xb7, 0x9b, 0x37, 0xc7, 0xc3, 0x37, 0xe7, 0xe3, 0x57,
    0x7f, 0xbf, 0xff, 0xab, 0xe7, 0xff, 0xd7, 0xff, 0xff, 0x67, 0x00, 0x00,
    0x8b, 0x00, 0x00, 0xb3, 0x00, 0x00, 0xd7, 0x00, 0x00, 0xff, 0x00, 0x00,
    0xff, 0xf3, 0x93, 0xff, 0xf7, 0xc7, 0xff, 0xff, 0xff, 0x9f, 0x5b, 0x53,
};

const anorms: [162][3]f32 = .{
    .{ -0.525731, 0.000000, 0.850651 },
    .{ -0.442863, 0.238856, 0.864188 },
    .{ -0.295242, 0.000000, 0.955423 },
    .{ -0.309017, 0.500000, 0.809017 },
    .{ -0.162460, 0.262866, 0.951056 },
    .{ 0.000000, 0.000000, 1.000000 },
    .{ 0.000000, 0.850651, 0.525731 },
    .{ -0.147621, 0.716567, 0.681718 },
    .{ 0.147621, 0.716567, 0.681718 },
    .{ 0.000000, 0.525731, 0.850651 },
    .{ 0.309017, 0.500000, 0.809017 },
    .{ 0.525731, 0.000000, 0.850651 },
    .{ 0.295242, 0.000000, 0.955423 },
    .{ 0.442863, 0.238856, 0.864188 },
    .{ 0.162460, 0.262866, 0.951056 },
    .{ -0.681718, 0.147621, 0.716567 },
    .{ -0.809017, 0.309017, 0.500000 },
    .{ -0.587785, 0.425325, 0.688191 },
    .{ -0.850651, 0.525731, 0.000000 },
    .{ -0.864188, 0.442863, 0.238856 },
    .{ -0.716567, 0.681718, 0.147621 },
    .{ -0.688191, 0.587785, 0.425325 },
    .{ -0.500000, 0.809017, 0.309017 },
    .{ -0.238856, 0.864188, 0.442863 },
    .{ -0.425325, 0.688191, 0.587785 },
    .{ -0.716567, 0.681718, -0.147621 },
    .{ -0.500000, 0.809017, -0.309017 },
    .{ -0.525731, 0.850651, 0.000000 },
    .{ 0.000000, 0.850651, -0.525731 },
    .{ -0.238856, 0.864188, -0.442863 },
    .{ 0.000000, 0.955423, -0.295242 },
    .{ -0.262866, 0.951056, -0.162460 },
    .{ 0.000000, 1.000000, 0.000000 },
    .{ 0.000000, 0.955423, 0.295242 },
    .{ -0.262866, 0.951056, 0.162460 },
    .{ 0.238856, 0.864188, 0.442863 },
    .{ 0.262866, 0.951056, 0.162460 },
    .{ 0.500000, 0.809017, 0.309017 },
    .{ 0.238856, 0.864188, -0.442863 },
    .{ 0.262866, 0.951056, -0.162460 },
    .{ 0.500000, 0.809017, -0.309017 },
    .{ 0.850651, 0.525731, 0.000000 },
    .{ 0.716567, 0.681718, 0.147621 },
    .{ 0.716567, 0.681718, -0.147621 },
    .{ 0.525731, 0.850651, 0.000000 },
    .{ 0.425325, 0.688191, 0.587785 },
    .{ 0.864188, 0.442863, 0.238856 },
    .{ 0.688191, 0.587785, 0.425325 },
    .{ 0.809017, 0.309017, 0.500000 },
    .{ 0.681718, 0.147621, 0.716567 },
    .{ 0.587785, 0.425325, 0.688191 },
    .{ 0.955423, 0.295242, 0.000000 },
    .{ 1.000000, 0.000000, 0.000000 },
    .{ 0.951056, 0.162460, 0.262866 },
    .{ 0.850651, -0.525731, 0.000000 },
    .{ 0.955423, -0.295242, 0.000000 },
    .{ 0.864188, -0.442863, 0.238856 },
    .{ 0.951056, -0.162460, 0.262866 },
    .{ 0.809017, -0.309017, 0.500000 },
    .{ 0.681718, -0.147621, 0.716567 },
    .{ 0.850651, 0.000000, 0.525731 },
    .{ 0.864188, 0.442863, -0.238856 },
    .{ 0.809017, 0.309017, -0.500000 },
    .{ 0.951056, 0.162460, -0.262866 },
    .{ 0.525731, 0.000000, -0.850651 },
    .{ 0.681718, 0.147621, -0.716567 },
    .{ 0.681718, -0.147621, -0.716567 },
    .{ 0.850651, 0.000000, -0.525731 },
    .{ 0.809017, -0.309017, -0.500000 },
    .{ 0.864188, -0.442863, -0.238856 },
    .{ 0.951056, -0.162460, -0.262866 },
    .{ 0.147621, 0.716567, -0.681718 },
    .{ 0.309017, 0.500000, -0.809017 },
    .{ 0.425325, 0.688191, -0.587785 },
    .{ 0.442863, 0.238856, -0.864188 },
    .{ 0.587785, 0.425325, -0.688191 },
    .{ 0.688191, 0.587785, -0.425325 },
    .{ -0.147621, 0.716567, -0.681718 },
    .{ -0.309017, 0.500000, -0.809017 },
    .{ 0.000000, 0.525731, -0.850651 },
    .{ -0.525731, 0.000000, -0.850651 },
    .{ -0.442863, 0.238856, -0.864188 },
    .{ -0.295242, 0.000000, -0.955423 },
    .{ -0.162460, 0.262866, -0.951056 },
    .{ 0.000000, 0.000000, -1.000000 },
    .{ 0.295242, 0.000000, -0.955423 },
    .{ 0.162460, 0.262866, -0.951056 },
    .{ -0.442863, -0.238856, -0.864188 },
    .{ -0.309017, -0.500000, -0.809017 },
    .{ -0.162460, -0.262866, -0.951056 },
    .{ 0.000000, -0.850651, -0.525731 },
    .{ -0.147621, -0.716567, -0.681718 },
    .{ 0.147621, -0.716567, -0.681718 },
    .{ 0.000000, -0.525731, -0.850651 },
    .{ 0.309017, -0.500000, -0.809017 },
    .{ 0.442863, -0.238856, -0.864188 },
    .{ 0.162460, -0.262866, -0.951056 },
    .{ 0.238856, -0.864188, -0.442863 },
    .{ 0.500000, -0.809017, -0.309017 },
    .{ 0.425325, -0.688191, -0.587785 },
    .{ 0.716567, -0.681718, -0.147621 },
    .{ 0.688191, -0.587785, -0.425325 },
    .{ 0.587785, -0.425325, -0.688191 },
    .{ 0.000000, -0.955423, -0.295242 },
    .{ 0.000000, -1.000000, 0.000000 },
    .{ 0.262866, -0.951056, -0.162460 },
    .{ 0.000000, -0.850651, 0.525731 },
    .{ 0.000000, -0.955423, 0.295242 },
    .{ 0.238856, -0.864188, 0.442863 },
    .{ 0.262866, -0.951056, 0.162460 },
    .{ 0.500000, -0.809017, 0.309017 },
    .{ 0.716567, -0.681718, 0.147621 },
    .{ 0.525731, -0.850651, 0.000000 },
    .{ -0.238856, -0.864188, -0.442863 },
    .{ -0.500000, -0.809017, -0.309017 },
    .{ -0.262866, -0.951056, -0.162460 },
    .{ -0.850651, -0.525731, 0.000000 },
    .{ -0.716567, -0.681718, -0.147621 },
    .{ -0.716567, -0.681718, 0.147621 },
    .{ -0.525731, -0.850651, 0.000000 },
    .{ -0.500000, -0.809017, 0.309017 },
    .{ -0.238856, -0.864188, 0.442863 },
    .{ -0.262866, -0.951056, 0.162460 },
    .{ -0.864188, -0.442863, 0.238856 },
    .{ -0.809017, -0.309017, 0.500000 },
    .{ -0.688191, -0.587785, 0.425325 },
    .{ -0.681718, -0.147621, 0.716567 },
    .{ -0.442863, -0.238856, 0.864188 },
    .{ -0.587785, -0.425325, 0.688191 },
    .{ -0.309017, -0.500000, 0.809017 },
    .{ -0.147621, -0.716567, 0.681718 },
    .{ -0.425325, -0.688191, 0.587785 },
    .{ -0.162460, -0.262866, 0.951056 },
    .{ 0.442863, -0.238856, 0.864188 },
    .{ 0.162460, -0.262866, 0.951056 },
    .{ 0.309017, -0.500000, 0.809017 },
    .{ 0.147621, -0.716567, 0.681718 },
    .{ 0.000000, -0.525731, 0.850651 },
    .{ 0.425325, -0.688191, 0.587785 },
    .{ 0.587785, -0.425325, 0.688191 },
    .{ 0.688191, -0.587785, 0.425325 },
    .{ -0.955423, 0.295242, 0.000000 },
    .{ -0.951056, 0.162460, 0.262866 },
    .{ -1.000000, 0.000000, 0.000000 },
    .{ -0.850651, 0.000000, 0.525731 },
    .{ -0.955423, -0.295242, 0.000000 },
    .{ -0.951056, -0.162460, 0.262866 },
    .{ -0.864188, 0.442863, -0.238856 },
    .{ -0.951056, 0.162460, -0.262866 },
    .{ -0.809017, 0.309017, -0.500000 },
    .{ -0.864188, -0.442863, -0.238856 },
    .{ -0.951056, -0.162460, -0.262866 },
    .{ -0.809017, -0.309017, -0.500000 },
    .{ -0.681718, 0.147621, -0.716567 },
    .{ -0.681718, -0.147621, -0.716567 },
    .{ -0.850651, 0.000000, -0.525731 },
    .{ -0.688191, 0.587785, -0.425325 },
    .{ -0.587785, 0.425325, -0.688191 },
    .{ -0.425325, 0.688191, -0.587785 },
    .{ -0.425325, -0.688191, -0.587785 },
    .{ -0.587785, -0.425325, -0.688191 },
    .{ -0.688191, -0.587785, -0.425325 },
};
