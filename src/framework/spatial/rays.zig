const std = @import("std");
const math = @import("../math.zig");
const debug = @import("../debug.zig");
const assert = std.debug.assert;

const Vec3 = math.Vec3;
const Plane = @import("plane.zig").Plane;
const BoundingBox = @import("boundingbox.zig").BoundingBox;
const OrientedBoundingBox = @import("orientedboundingbox.zig").OrientedBoundingBox;

pub const RayIntersection = struct {
    hit_pos: Vec3,
    normal: Vec3,
};

pub const Ray = struct {
    pos: Vec3,
    dir: Vec3,

    /// Creates a new ray based on a start position and direction
    pub fn init(position: Vec3, direction: Vec3) Ray {
        return Ray{
            .pos = position,
            .dir = direction,
        };
    }

    /// Returns an intersection point if a ray crosses a plane
    pub fn intersectPlane(self: *const Ray, plane: Plane, ignore_backfacing: bool) ?RayIntersection {
        if (ignore_backfacing) {
            const hit = plane.intersectRayIgnoreBack(self.pos, self.dir);
            if (hit) |h| {
                return .{ .hit_pos = h, .normal = plane.normal };
            }
            return null;
        }

        const hit = plane.intersectRay(self.pos, self.dir);
        if (hit) |h| {
            return .{ .hit_pos = h, .normal = plane.normal };
        }
        return null;
    }

    /// Returns an intersection point if a ray crosses an axis aligned bounding box
    pub fn intersectBoundingBox(self: *const Ray, bounds: BoundingBox) ?Vec3 {
        return bounds.intersectRay(self.pos, self.dir);
    }

    /// Returns an intersection point if a ray crosses an axis aligned bounding box
    pub fn intersectOrientedBoundingBox(self: *const Ray, bounds: OrientedBoundingBox) ?Vec3 {
        return bounds.intersectRay(self.pos, self.dir);
    }
};

test "Ray.intersectPlane" {
    const plane = Plane.init(Vec3.new(0, 0, 1), Vec3.new(0, 0, 5));

    const hit0 = Ray.init(Vec3.new(0, 0, 0), Vec3.new(0, 1, 0)).intersectPlane(plane, false);
    const hit1 = Ray.init(Vec3.new(0, 0, 0), Vec3.new(0, 0, 1)).intersectPlane(plane, false);
    const hit2 = Ray.init(Vec3.new(0, 0, 0), Vec3.new(0, 0, -1)).intersectPlane(plane, false);
    const hit3 = Ray.init(Vec3.new(0, 0, 10), Vec3.new(0, 0, -1)).intersectPlane(plane, false);

    assert(hit0 == null);
    assert(std.meta.eql(hit1.?.hit_pos, Vec3.new(0, 0, 5)));
    assert(hit2 == null);
    assert(std.meta.eql(hit3.?.hit_pos, Vec3.new(0, 0, 5)));
}

test "Ray.intersectBoundingBox" {
    const ray = Ray.init(Vec3.new(0, 2, 0), Vec3.x_axis);
    const box = BoundingBox.init(Vec3.new(10, 0, 0), Vec3.new(2, 4, 2));

    const hit = ray.intersectBoundingBox(box);
    assert(hit != null);
    assert(hit.?.x == 9.0);
    assert(hit.?.y == 2.0);
    assert(hit.?.z == 0.0);
}

test "Ray.intersectOrientedBoundingBox" {
    const ray = Ray.init(Vec3.new(0, 2, 0), Vec3.x_axis);
    const box = OrientedBoundingBox.init(Vec3.new(10, 0, 0), Vec3.new(2, 4, 2), math.Mat4.identity);

    const hit = ray.intersectOrientedBoundingBox(box);
    assert(hit != null);
    assert(hit.?.x == 9.0);
    assert(hit.?.y == 2.0);
    assert(hit.?.z == 0.0);
}
