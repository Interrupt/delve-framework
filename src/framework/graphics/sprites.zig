const math = @import("../math.zig");

const Vec2 = math.Vec2;

/// Keeps track of a sub region of a texture
/// Origin is in the upper left, x axis points right, and y axis points down
pub const TextureRegion = struct {
    u: f32 = 0,
    v: f32 = 0,
    u_2: f32 = 1.0,
    v_2: f32 = 1.0,

    /// Returns the default 0,0,1,1 region
    pub fn default() TextureRegion {
        return .{ .u = 0.0, .v = 0.0, .u_2 = 1.0, .v_2 = 1.0 };
    }

    /// Returns a region flipped vertically
    pub fn flipY(self: TextureRegion) TextureRegion {
        return .{ .u = self.u, .v = self.v_2, .u_2 = self.u_2, .v_2 = self.v };
    }

    /// Returns a region flipped horizontally
    pub fn flipX(self: TextureRegion) TextureRegion {
        return .{ .u = self.u_2, .v = self.v, .u_2 = self.u, .v_2 = self.v_2 };
    }

    /// Returns the size of this region
    pub fn getSize(self: TextureRegion) Vec2 {
        return Vec2.new(self.u_2 - self.u, self.v_2 - self.v);
    }

    /// Returns a region that has been offset by a given amount
    pub fn scroll(self: TextureRegion, amount: Vec2) TextureRegion {
        return .{ .u = self.u + amount.x, .v = self.v + amount.y, .u_2 = self.u_2 + amount.x, .v_2 = self.v_2 + amount.y };
    }
};
