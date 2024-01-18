
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
        var mesh_normals = std.ArrayList([3]f32).init(allocator);
        var mesh_texcoords = std.ArrayList([2]f32).init(allocator);

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

        // Make our default uniform blocks
        material.vs_uniforms = graphics.MaterialUniformBlock.init(allocator);
        material.fs_uniforms = graphics.MaterialUniformBlock.init(allocator);

        return Mesh{ .bindings = bindings, .material = material};
    }

    pub fn deinit(self: *Mesh) void {
        self.bindings.destroy();
    }

    pub fn draw(self: *Mesh, proj_view_matrix: math.Mat4, model_matrix: math.Mat4) void {
        // set the default vertex shader uniform block
        var vs_uniforms = &self.material.vs_uniforms.?;
        vs_uniforms.begin();
        vs_uniforms.addMatrix("u_projViewMatrix", proj_view_matrix);
        vs_uniforms.addMatrix("u_modelMatrix", model_matrix);
        vs_uniforms.addColor("u_color", self.material.params.draw_color);
        vs_uniforms.end();

        // set the default fragment shader uniform block
        var fs_uniforms = &self.material.fs_uniforms.?;
        fs_uniforms.begin();
        fs_uniforms.addColor("u_color_override", self.material.params.color_override);
        fs_uniforms.addFloat("u_alpha_cutoff", self.material.params.alpha_cutoff);
        fs_uniforms.end();

        // set our default vs/fs uniforms to the 0 slots
        self.material.shader.applyUniformBlock(.VS, 0, graphics.asAnything(self.material.vs_uniforms.?.bytes.items));
        self.material.shader.applyUniformBlock(.FS, 0, graphics.asAnything(self.material.fs_uniforms.?.bytes.items));

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
