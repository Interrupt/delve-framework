const std = @import("std");
const math = @import("../math.zig");
const plane = @import("plane.zig");
const assert = std.debug.assert;

const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Plane = plane.Plane;

/// A view frustum is composed of six planes: left, right, top, bottom, front and back
pub const Frustum = struct {
    planes: [6]Plane,
    corners: [8]Vec3,

    /// Creates a frustum from a view matrix
    pub fn init(proj_view: Mat4) Frustum {
        const inv_proj_view = proj_view.invert();

        // corners in clip space
        const frustum_corners_clip = [_]math.Vec4{
            math.Vec4.new(-1.0, -1.0, 1.0, 1.0), // left, bottom, far
            math.Vec4.new(-1.0, 1.0, 1.0, 1.0), // left, top, far
            math.Vec4.new(1.0, -1.0, 1.0, 1.0), // right, bottom, far
            math.Vec4.new(1.0, 1.0, 1.0, 1.0), // right, top, far
            math.Vec4.new(-1.0, -1.0, -1.0, 1.0), // left, bottom, near
            math.Vec4.new(-1.0, 1.0, -1.0, 1.0), // left, top, near
            math.Vec4.new(1.0, -1.0, -1.0, 1.0), // right, bottom, near
            math.Vec4.new(1.0, 1.0, -1.0, 1.0), // right, top, near
        };

        // corners in world space
        const frustum_corners = [_]math.Vec3{
            frustum_corners_clip[0].mulMat4(inv_proj_view).toVec3(),
            frustum_corners_clip[1].mulMat4(inv_proj_view).toVec3(),
            frustum_corners_clip[2].mulMat4(inv_proj_view).toVec3(),
            frustum_corners_clip[3].mulMat4(inv_proj_view).toVec3(),
            frustum_corners_clip[4].mulMat4(inv_proj_view).toVec3(),
            frustum_corners_clip[5].mulMat4(inv_proj_view).toVec3(),
            frustum_corners_clip[6].mulMat4(inv_proj_view).toVec3(),
            frustum_corners_clip[7].mulMat4(inv_proj_view).toVec3(),
        };

        return Frustum {
            .planes = [6]Plane{
                Plane.initFromTriangle(frustum_corners[2], frustum_corners[1], frustum_corners[0]), // far plane
                Plane.initFromTriangle(frustum_corners[4], frustum_corners[5], frustum_corners[6]), // near plane
                Plane.initFromTriangle(frustum_corners[4], frustum_corners[1], frustum_corners[0]), // left plane
                Plane.initFromTriangle(frustum_corners[6], frustum_corners[2], frustum_corners[3]), // right plane
                Plane.initFromTriangle(frustum_corners[1], frustum_corners[3], frustum_corners[5]), // top plane
                Plane.initFromTriangle(frustum_corners[4], frustum_corners[2], frustum_corners[0]), // bottom plane
            },
            .corners = frustum_corners,
        };
    }

    /// Check to see if this frustum contains this point
    pub fn containsPoint(self: *const Frustum, point: Vec3) bool {
        // frustum contains a point if it is in front of all planes
        // for(self.planes) |p| {
        //     if(p.testPoint(point) == .BACK)
        //         return false;
        // }

        // far test
        if(self.planes[0].testPoint(point) == .FRONT)
            return false;

        // near test
        if(self.planes[1].testPoint(point) == .FRONT)
            return false;

        // left test
        if(self.planes[2].testPoint(point) == .BACK)
            return false;

        // right test
        if(self.planes[3].testPoint(point) == .BACK)
            return false;

        // top test
        if(self.planes[4].testPoint(point) == .FRONT)
            return false;

        // bottom test
        if(self.planes[5].testPoint(point) == .FRONT)
            return false;

        return true;
    }
};

test "Frustum.init" {
    const proj_mat = Mat4.ortho(-2, 3, -4, 5, 0.1, 21);
    const view_mat = Mat4.lookat(Vec3.new(0,0,0), Vec3.zero.add(Vec3.new(0,0,1)), Vec3.up);
    const frustum = Frustum.init(proj_mat.mul(view_mat));

    // std.debug.print("\n", .{});
    // for(frustum.planes) |p| {
    //     std.debug.print("plane: {}\n", .{p});
    // }

    assert(std.meta.eql(frustum.planes[0].normal, Vec3.new(0,0,-1))); // far
    assert(std.meta.eql(frustum.planes[1].normal, Vec3.new(0,0,1))); // near
    assert(std.meta.eql(frustum.planes[2].normal, Vec3.new(1,0,0))); // left
    assert(std.meta.eql(frustum.planes[3].normal, Vec3.new(-1,0,0))); // right
    assert(std.meta.eql(frustum.planes[4].normal, Vec3.new(0,-1,0))); // top
    assert(std.meta.eql(frustum.planes[5].normal, Vec3.new(0,1,0))); // bottom
}
