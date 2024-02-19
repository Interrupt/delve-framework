const std = @import("std");
const math = @import("../math.zig");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const assert = std.debug.assert;

const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

/// A bounding box oriented using a transform matrix
pub const OrientedBoundingBox = struct {
    min: Vec3,
    max: Vec3,
    center: Vec3,
    transform: Mat4 = math.Mat4.identity,

    /// Creates a new bounding box based on a position and size
    pub fn init(position: Vec3, size: Vec3, transform_matrix: Mat4) OrientedBoundingBox {
        const half_size = size.scale(0.5);
        return OrientedBoundingBox{
            .center = position,
            .min = position.sub(half_size),
            .max = position.add(half_size),
            .transform = transform_matrix,
        };
    }

    /// Scale this bounding box
    pub fn scale(self: *const OrientedBoundingBox, scale_by: f32) OrientedBoundingBox {
        var ret = self.*;
        ret.min = ret.min.scale(scale_by);
        ret.max = ret.max.scale(scale_by);
        return ret;
    }

    /// Translate this bounding box
    pub fn translate(self: *const OrientedBoundingBox, move_by: Vec3) OrientedBoundingBox {
        var ret = self.*;
        ret.center = ret.center.add(move_by);
        ret.min = ret.min.add(move_by);
        ret.max = ret.max.add(move_by);
        return ret;
    }

    /// Increase the size of this bounding box
    pub fn inflate(self: *const OrientedBoundingBox, amount: f32) OrientedBoundingBox {
        const increase_by = Vec3.new(amount, amount, amount);

        var ret = self.*;
        ret.min = ret.min.sub(increase_by);
        ret.max = ret.max.add(increase_by);
        return ret;
    }

    /// Transforms this bounding box by a matrix
    pub fn transform(self: *const OrientedBoundingBox, transform_mat: math.Mat4) OrientedBoundingBox {
        var ret = self.*;
        ret.transform = self.transform.mul(transform_mat);
        return ret;
    }

    /// Checks if two oriented bounding boxes overlap
    pub fn overlaps(self: *const OrientedBoundingBox, other: OrientedBoundingBox) bool {
        const a_origin: Vec3 = Vec3.zero.mulMat4(self.transform);
        const a_axes: [3]Vec3 = [_]Vec3{
            Vec3.x_axis.mulMat4(self.transform).sub(a_origin).norm(),
            Vec3.y_axis.mulMat4(self.transform).sub(a_origin).norm(),
            Vec3.z_axis.mulMat4(self.transform).sub(a_origin).norm(),
        };

        const b_origin: Vec3 = Vec3.zero.mulMat4(other.transform);
        const b_axes: [3]Vec3 = [_]Vec3{
            Vec3.x_axis.mulMat4(other.transform).sub(b_origin).norm(),
            Vec3.y_axis.mulMat4(other.transform).sub(b_origin).norm(),
            Vec3.z_axis.mulMat4(other.transform).sub(b_origin).norm(),
        };

        const all_axes: [24]Vec3 = [_]Vec3{
            a_axes[0],
            a_axes[1],
            a_axes[2],
            b_axes[0],
            b_axes[1],
            b_axes[2],
            a_axes[0].cross(b_axes[0]),
            a_axes[0].cross(b_axes[1]),
            a_axes[0].cross(b_axes[2]),
            a_axes[1].cross(b_axes[0]),
            a_axes[1].cross(b_axes[1]),
            a_axes[1].cross(b_axes[2]),
            a_axes[2].cross(b_axes[0]),
            a_axes[2].cross(b_axes[1]),
            a_axes[2].cross(b_axes[2]),
            a_axes[0].scale(-1).cross(b_axes[0]),
            a_axes[0].scale(-1).cross(b_axes[1]),
            a_axes[0].scale(-1).cross(b_axes[2]),
            a_axes[1].scale(-1).cross(b_axes[0]),
            a_axes[1].scale(-1).cross(b_axes[1]),
            a_axes[1].scale(-1).cross(b_axes[2]),
            a_axes[2].scale(-1).cross(b_axes[0]),
            a_axes[2].scale(-1).cross(b_axes[1]),
            a_axes[2].scale(-1).cross(b_axes[2]),
        };

        var a_corners = self.getCorners();
        var b_corners = other.getCorners();

        return intersects(&all_axes, &a_corners, &b_corners);
    }

    /// Checks if two geometries are intersecting, using the seperating axes theorem.
    fn intersects(check_axes: []const Vec3, a_vertices: []const Vec3, b_vertices: []const Vec3) bool {
        for (check_axes) |axis| {
            var min_a: f32 = std.math.floatMax(f32);
            var max_a: f32 = std.math.floatMin(f32);

            // project shape A on an axis
            for (a_vertices) |vert| {
                const p = vert.dot(axis);
                min_a = @min(min_a, p);
                max_a = @max(max_a, p);
            }

            var min_b: f32 = std.math.floatMax(f32);
            var max_b: f32 = std.math.floatMin(f32);

            // project shape A on an axis
            for (b_vertices) |vert| {
                const p = vert.dot(axis);
                min_b = @min(min_b, p);
                max_b = @max(max_b, p);
            }

            if (max_a < min_b or max_b < min_a) {
                // found a separating axis, so not intersecting
                return false;
            }
        }

        // found no separating axes, so these shapes must be overlapping!
        return true;
    }

    /// Returns locations of all the corners
    pub fn getCorners(self: *const OrientedBoundingBox) [8]Vec3 {
        return [8]Vec3{
            Vec3.new(self.min.x, self.max.y, self.min.z).mulMat4(self.transform),
            Vec3.new(self.max.x, self.max.y, self.max.z).mulMat4(self.transform),
            Vec3.new(self.max.x, self.max.y, self.min.z).mulMat4(self.transform),
            Vec3.new(self.min.x, self.max.y, self.max.z).mulMat4(self.transform),
            Vec3.new(self.min.x, self.min.y, self.min.z).mulMat4(self.transform),
            Vec3.new(self.max.x, self.min.y, self.max.z).mulMat4(self.transform),
            Vec3.new(self.max.x, self.min.y, self.min.z).mulMat4(self.transform),
            Vec3.new(self.min.x, self.min.y, self.max.z).mulMat4(self.transform),
        };
    }

    // /// Check to see if this bounding box contains a point
    // pub fn contains(self: *const BoundingBox, point: Vec3) bool {
    //     return point.x >= self.min.x and point.y >= self.min.y and point.z >= self.min.z and
    //         point.x <= self.max.x and point.y <= self.max.y and point.z <= self.max.z;
    // }
    //
    // /// Check to see if this bounding box contains part or all of another
    // pub fn intersects(self: *const BoundingBox, other: BoundingBox) bool {
    //     return other.max.x >= self.min.x and other.max.y >= self.min.y and other.max.z >= self.min.z and
    //         other.min.x <= self.max.x and other.min.y <= self.max.y and other.min.z <= self.max.z;
    // }
};
