const std = @import("std");
const math = @import("../math.zig");
const debug = @import("../debug.zig");
const boundingbox = @import("boundingbox.zig");
const assert = std.debug.assert;

const Vec3 = math.Vec3;

// Based a lot on the LibGdx plane class

pub const PlaneFacing = enum(i32) {
    ON_PLANE,
    BACK,
    FRONT
};

pub const Plane = struct {
    normal: Vec3,
    d: f32,

    /// Creates a plane from a normal and a point on the plane
    pub fn init(normal: Vec3, point: Vec3) Plane {
        const norm = normal.norm();
        return Plane {
            .normal = norm,
            .d = -norm.dot(point),
        };
    }

    /// Creates a plane from a normal and distance to the origin
    pub fn initFromDistance(normal: Vec3, distance: f32) Plane {
        return Plane {
            .normal = normal.norm(),
            .d = distance,
        };
    }

    /// Creates a plane from three points
    /// Calculated via a cross product between (point1-point2)x(point2-point3)
    pub fn initFromTriangle(v0: Vec3, v1: Vec3, v2: Vec3) Plane {
        var norm: Vec3 = v0.sub(v1).cross(v1.sub(v2)).norm();
        var d: f32 = v0.dot(norm);

        return Plane {
            .normal = norm,
            .d = d,
        };
    }

    /// Returns the shortest distance between the plane and the point
    pub fn distanceToPoint(self: *const Plane, point: Vec3) f32 {
        return self.normal.dot(point) + self.d;
    }

    /// Returns which side of the plane this point is on
    pub fn testPoint(self: *const Plane, point: Vec3) PlaneFacing {
        const distance = self.distanceToPoint(point);

        if(distance == 0) {
            return .ON_PLANE;
        } else if(distance < 0) {
            return .BACK;
        } else {
            return .FRONT;
        }
    }

    /// Returns which side of the plane this bounding box is on, or ON_PLANE for intersections
    pub fn testBoundingBox(self: *const Plane, bounds: boundingbox.BoundingBox) PlaneFacing {
        var facing: ?PlaneFacing = null;

        for(bounds.getCorners()) |point| {
            const distance = self.distanceToPoint(point);

            var this_facing: PlaneFacing = undefined;
            if(distance == 0) {
                this_facing = .ON_PLANE;
            } else if(distance < 0) {
                this_facing = .BACK;
            } else {
                this_facing = .FRONT;
            }

            if(facing == null) {
                facing = this_facing;
            } else if(facing != this_facing) {
                // facing changed, we must be intersecting!
                return .ON_PLANE;
            }
        }

        return facing.?;
    }

    /// If direction is a camera direction, this returns true if the front of the plane would be
    /// visible from the camera.
    pub fn facesDirection(self: *const Plane, direction: Vec3) bool {
        return self.normal.dot(direction) <= 0;
    }

    /// Returns an intersection point if a line crosses a plane
    pub fn intersectLine(self: *const Plane, start: Vec3, end: Vec3) ?Vec3 {
        const dir = end.sub(start);
        const denom = dir.dot(self.normal);

        if(denom == 0)
            return null;

       	const t = -(start.dot(self.normal) + self.d) / denom;
        if(t < 0 or t > 1)
            return null;

        return start.add(dir.scale(t));
    }

    /// Returns an intersection point if a ray crosses a plane
    pub fn intersectRay(self: *const Plane, start: Vec3, dir: Vec3) ?Vec3 {
        var norm_dir = dir.norm();
        const denom = norm_dir.dot(self.normal);

        if(denom == 0)
            return null;

       	const t = -(start.dot(self.normal) + self.d) / denom;

        // ignore intersections behind the ray
        if(t < 0)
            return null;

        return start.add(norm_dir.scale(t));
    }

    /// Returns the intersection point of three non-parallel planes
    /// From the Celeste64 source
    pub fn planeIntersectPoint(a: Plane, b: Plane, c: Plane) Vec3 {
        // Formula used
		//                d1 ( N2 * N3 ) + d2 ( N3 * N1 ) + d3 ( N1 * N2 )
		//P =   -------------------------------------------------------------------------
		//                             N1 . ( N2 * N3 )
		//
		// Note: N refers to the normal, d refers to the displacement. '.' means dot product. '*' means cross product

		const f = -a.normal.dot(b.normal.cross(c.normal));
		const v1 = b.normal.cross(c.normal).scale(a.d);
		const v2 = c.normal.cross(a.normal).scale(b.d);
		const v3 = a.normal.cross(b.normal).scale(c.d);

        // (v1 + v2 + v3) / f
        const ret = v1.add(v2).add(v3);
        return ret.scale(1.0 / f);
    }

    pub fn normalize(self: *const Plane) Plane {
        var ret = self.*;
        const scale = 1.0 / self.normal.len();

        // normalize the normal, and adjust d the same amount
        ret.normal = ret.normal.norm();
        ret.d *= scale;

        return ret;
    }
};

test "Plane.distanceToPoint" {
    const plane = Plane.init(Vec3.new(0, 1, 0), Vec3.new(0,10,0));

    assert(plane.testPoint(Vec3.new(0,10,0)) == .ON_PLANE);
    assert(plane.distanceToPoint(Vec3.new(0,15,0)) == 5);
    assert(plane.distanceToPoint(Vec3.new(110,15,2000)) == 5);
    assert(plane.distanceToPoint(Vec3.new(110,5,2000)) == -5);
}

test "Plane.testPoint" {
    const plane = Plane.init(Vec3.new(0, 0, 1), Vec3.new(0,10,5));

    assert(plane.testPoint(Vec3.new(0,10,5)) == .ON_PLANE);
    assert(plane.testPoint(Vec3.new(0,10,7)) == .FRONT);
    assert(plane.testPoint(Vec3.new(0,10,-5)) == .BACK);
}

test "Plane.testBoundingBox" {
    const plane = Plane.init(Vec3.new(0, 0, 1), Vec3.new(0,0,0));

    // intersects
    const bounds1 = boundingbox.BoundingBox.init(Vec3.new(0,0,0), Vec3.new(2,2,2));
    assert(plane.testBoundingBox(bounds1) == .ON_PLANE);

    // in front
    const bounds2 = boundingbox.BoundingBox.init(Vec3.new(0,0,8), Vec3.new(2,2,2));
    assert(plane.testBoundingBox(bounds2) == .FRONT);

    // behind
    const bounds3 = boundingbox.BoundingBox.init(Vec3.new(0,0,-8), Vec3.new(2,2,2));
    assert(plane.testBoundingBox(bounds3) == .BACK);
}

test "Plane.facesDirection" {
    const plane = Plane.init(Vec3.new(0, 0, 1), Vec3.new(0,0,0));

    assert(plane.facesDirection(Vec3.new(0,0,1)) == false);
    assert(plane.facesDirection(Vec3.new(0,0,-1)) == true);
}

test "Plane.intersectLine" {
    const plane = Plane.init(Vec3.new(0, 0, 1), Vec3.new(0,0,5));

    assert(plane.intersectLine(Vec3.new(0,0,0), Vec3.new(10,0,0)) == null);
    assert(plane.intersectLine(Vec3.new(0,0,-5), Vec3.new(10,0,10)) != null);
    assert(std.meta.eql(plane.intersectLine(Vec3.new(0,0,-5), Vec3.new(0,0,15)).?, Vec3.new(0,0,5)));
}

test "Plane.intersectRay" {
    const plane = Plane.init(Vec3.new(0, 0, 1), Vec3.new(0,0,5));

    assert(plane.intersectRay(Vec3.new(0,0,0), Vec3.new(0,1,0)) == null);
    assert(std.meta.eql(plane.intersectRay(Vec3.new(0,0,0), Vec3.new(0,0,1)), Vec3.new(0,0,5)));
    assert(plane.intersectRay(Vec3.new(0,0,0), Vec3.new(0,0,-1)) == null);
    assert(std.meta.eql(plane.intersectRay(Vec3.new(0,0,10), Vec3.new(0,0,-1)), Vec3.new(0,0,5)));
}

test "Plane.planeIntersectPoint" {
    const plane1 = Plane.init(Vec3.new(0, 0, 1), Vec3.new(1,0,5));
    const plane2 = Plane.init(Vec3.new(1, 0, 0), Vec3.new(1,1,5));
    const plane3 = Plane.init(Vec3.new(0, 1, 0), Vec3.new(0,4,5));

    const intersect = Plane.planeIntersectPoint(plane1, plane2, plane3);
    assert(intersect.x == 1);
    assert(intersect.y == 4);
    assert(intersect.z == 5);
}
