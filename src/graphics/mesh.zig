
const graphics = @import("../platform/graphics.zig");

pub const Mesh = struct {
    bindings: graphics.Bindings,

    pub fn draw(self: *Mesh) void {
        if(self == null)
            return;

        graphics.draw(self.?);
    }
};

pub fn createMesh(vertices: []graphics.Vertex, indices: []u16) Mesh {
    const m: Mesh = Mesh {
        .bindings = graphics.Bindings{
            .vertex_buffer = vertices,
            .index_buffer = indices,
            .bindings = *graphics.createBindings(vertices, indices),
        },
    };
    return m;
}
