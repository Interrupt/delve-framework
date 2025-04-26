const std = @import("std");
const graphics = @import("../platform/graphics.zig");
const debug = @import("../debug.zig");
const zmesh = @import("zmesh");
const images = @import("../images.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub const Data = zmesh.io.zcgltf.Data;

pub fn freeData(data: ?*Data) void {
    if (data != null) {
        zmesh.io.zcgltf.free(data.?);
    }
}

pub fn loadData(filename: [:0]const u8, path: [:0]const u8) !*zmesh.io.zcgltf.Data {
    const src = std.fs.path.joinZ(allocator, &[_][]const u8{ path, filename }) catch |err| {
        debug.log("cannot create src: {}", .{err});
        return err;
    };
    defer allocator.free(src);

    return zmesh.io.parseAndLoadFile(src) catch |err| {
        debug.log("Could not load mesh file {s}", .{filename});
        return err;
    };
}

pub fn loadTexture(texture: ?*zmesh.io.zcgltf.Texture, path: [:0]const u8) ?graphics.Texture {
    if (texture != null) {
        const u = texture.?.image.?.uri;
        if (u) |uri| {
            const image_path = std.fs.path.joinZ(allocator, &[_][]const u8{ path, std.mem.span(uri) }) catch |err| {
                debug.log("cannot create src: {}", .{err});
                return null;
            };
            defer allocator.free(image_path);

            var base_img: images.Image = images.loadFile(image_path) catch {
                debug.log("Assets: Error loading image asset: {s}", .{image_path});
                return null;
            };
            defer base_img.deinit();

            return graphics.Texture.init(base_img);
        }
    }
    return null;
}

pub fn loadMaterials(data: *zmesh.io.zcgltf.Data, mesh_index: usize, path: [:0]const u8, shader: graphics.Shader, materials: *std.ArrayList(graphics.Material)) void {
    const dmesh = data.meshes.?[mesh_index];
    for (0..dmesh.primitives_count) |primitive_index| {
        const primitive = dmesh.primitives[primitive_index];

        const zcgltf_material = primitive.material;
        if (zcgltf_material != null) {
            var texture_0: ?graphics.Texture = undefined;
            // var texture_1: ?graphics.Texture = undefined;

            std.debug.print("Loading material: {?s} \n", .{zcgltf_material.?.name});

            const base_color_texture = zcgltf_material.?.pbr_metallic_roughness.base_color_texture.texture;
            texture_0 = loadTexture(base_color_texture, path);
            // const normal_texture = zcgltf_material.?.normal_texture.texture;
            // texture_1 = loadTexture(allocator, normal_texture, path);

            // Create a material out of our shader and textures
            const material = graphics.Material.init(.{
                .shader = shader,
                .texture_0 = texture_0,
            }) catch |err| {
                std.debug.print("Failed to create material {}\n", .{err});
                continue;
            };
            materials.append(material) catch |err| {
                std.debug.print("Failed to append material {}\n", .{err});
            };
        }
    }
}
