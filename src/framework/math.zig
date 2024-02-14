//------------------------------------------------------------------------------
//  math.zig
//
//  minimal vector math helper functions, just the stuff needed for
//  the sokol-samples
//
//  Ported from HandmadeMath.h
//------------------------------------------------------------------------------
const std = @import("std");
const assert = std.debug.assert;
const math = std.math;

fn radians(deg: f32) f32 {
    return deg * (math.pi / 180.0);
}

pub fn vec2(x: f32, y: f32) Vec2 {
    return Vec2{ .x = x, .y = y };
}

pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub fn fromArray(val: [2]f32) Vec2 {
        return Vec2{ .x = val[0], .y = val[1] };
    }

    pub fn new(x: f32, y: f32) Vec2 {
        return Vec2{ .x = x, .y = y };
    }

    pub fn len(v: *const Vec2) f32 {
        return math.sqrt(v.dot(Vec2.new(v.x, v.y)));
    }

    pub fn add(left: *const Vec2, right: Vec2) Vec2 {
        return Vec2{ .x = left.x + right.x, .y = left.y + right.y };
    }

    pub fn sub(left: *const Vec2, right: Vec2) Vec2 {
        return Vec2{ .x = left.x - right.x, .y = left.y - right.y };
    }

    pub fn scale(v: *const Vec2, s: f32) Vec2 {
        return Vec2{ .x = v.x * s, .y = v.y * s };
    }

    pub fn mul(left: *const Vec2, right: Vec2) Vec2 {
        return Vec2{ .x = left.x * right.x, .y = left.y * right.y };
    }

    pub fn norm(v: *const Vec2) Vec2 {
        const l = Vec2.len(v);
        if (l != 0.0) {
            return Vec2{ .x = v.x / l, .y = v.y / l };
        } else {
            return Vec2.zero;
        }
    }

    pub fn dot(v0: *const Vec2, v1: Vec2) f32 {
        return v0.x * v1.x + v0.y * v1.y;
    }

    pub fn angleRadians(self: *const Vec2) f32 {
        return std.math.atan2(f32, self.y, self.x);
    }

    pub fn angleDegrees(self: *const Vec2) f32 {
        return std.math.atan2(f32, self.y, self.x) * (360.0 / (std.math.tau));
    }

    pub const zero = Vec2.new(0.0, 0.0);
    pub const one = Vec2.new(1.0, 1.0);
    pub const x_axis = Vec2.new(1.0, 0.0);
    pub const y_axis = Vec2.new(0.0, 1.0);
};

pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3{ .x = x, .y = y, .z = z };
}

pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn fromArray(val: [3]f32) Vec3 {
        return Vec3{ .x = val[0], .y = val[1], .z = val[2] };
    }

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn len(v: *const Vec3) f32 {
        return math.sqrt(v.dot(Vec3.new(v.x, v.y, v.z)));
    }

    pub fn add(left: *const Vec3, right: Vec3) Vec3 {
        return Vec3{ .x = left.x + right.x, .y = left.y + right.y, .z = left.z + right.z };
    }

    pub fn sub(left: *const Vec3, right: Vec3) Vec3 {
        return Vec3{ .x = left.x - right.x, .y = left.y - right.y, .z = left.z - right.z };
    }

    pub fn scale(v: *const Vec3, s: f32) Vec3 {
        return Vec3{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn mul(left: *const Vec3, right: Vec3) Vec3 {
        return Vec3{ .x = left.x * right.x, .y = left.y * right.y, .z = left.z * right.z };
    }

    pub fn norm(v: *const Vec3) Vec3 {
        const l = Vec3.len(v);
        if (l != 0.0) {
            return Vec3{ .x = v.x / l, .y = v.y / l, .z = v.z / l };
        } else {
            return Vec3.zero;
        }
    }

    pub fn cross(v0: *const Vec3, v1: Vec3) Vec3 {
        return Vec3{ .x = (v0.y * v1.z) - (v0.z * v1.y), .y = (v0.z * v1.x) - (v0.x * v1.z), .z = (v0.x * v1.y) - (v0.y * v1.x) };
    }

    pub fn dot(v0: *const Vec3, v1: Vec3) f32 {
        return v0.x * v1.x + v0.y * v1.y + v0.z * v1.z;
    }

    pub fn mulMat4(left: *const Vec3, right: Mat4) Vec3 {
        var res = Vec3.zero;
        res.x += left.x * right.m[0][0];
        res.y += left.x * right.m[0][1];
        res.z += left.x * right.m[0][2];
        res.x += left.y * right.m[1][0];
        res.y += left.y * right.m[1][1];
        res.z += left.y * right.m[1][2];
        res.x += left.z * right.m[2][0];
        res.y += left.z * right.m[2][1];
        res.z += left.z * right.m[2][2];
        res.x += 1.0 * right.m[3][0];
        res.y += 1.0 * right.m[3][1];
        res.z += 1.0 * right.m[3][2];
        return res;
    }

    pub fn rotate(left: *const Vec3, angle: f32, axis: Vec3) Vec3 {
        // Using the Euler–Rodrigues formula
        const axis_norm = axis.norm();

        const half_angle = radians(angle) * 0.5;
        const angle_sin = std.math.sin(half_angle);
        const angle_cos = std.math.cos(half_angle);

        const w = axis_norm.scale(angle_sin);
        const wv = w.cross(left.*);
        const wwv = w.cross(wv);

        const swv = wv.scale(angle_cos * 2.0);
        const swwv = wwv.scale(2.0);

        return left.add(swv).add(swwv);
    }

    pub fn min(left: Vec3, right: Vec3) Vec3 {
        return Vec3.new(@min(left.x, right.x), @min(left.y, right.y), @min(left.z, right.z));
    }

    pub fn max(left: Vec3, right: Vec3) Vec3 {
        return Vec3.new(@max(left.x, right.x), @max(left.y, right.y), @max(left.z, right.z));
    }

    pub const zero = Vec3.new(0.0, 0.0, 0.0);
    pub const one = Vec3.new(1.0, 1.0, 1.0);
    pub const x_axis = Vec3.new(1.0, 0.0, 0.0);
    pub const y_axis = Vec3.new(0.0, 1.0, 0.0);
    pub const z_axis = Vec3.new(0.0, 0.0, 1.0);
    pub const up = Vec3.new(0.0, 1.0, 0.0);
    pub const down = Vec3.new(0.0, -1.0, 0.0);
};

pub const Mat4 = extern struct {
    m: [4][4]f32,

    pub fn mul(left: *const Mat4, right: Mat4) Mat4 {
        var res = Mat4.zero;
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var row: usize = 0;
            while (row < 4) : (row += 1) {
                res.m[col][row] = left.m[0][row] * right.m[col][0] +
                    left.m[1][row] * right.m[col][1] +
                    left.m[2][row] * right.m[col][2] +
                    left.m[3][row] * right.m[col][3];
            }
        }
        return res;
    }

    pub fn transpose(self: *const Mat4) Mat4 {
        var res = Mat4.zero;
        res.m[0][0] = self.m[0][0];
        res.m[0][1] = self.m[1][0];
        res.m[0][2] = self.m[2][0];
        res.m[0][3] = self.m[3][0];
        res.m[1][0] = self.m[0][1];
        res.m[1][1] = self.m[1][1];
        res.m[1][2] = self.m[2][1];
        res.m[1][3] = self.m[3][1];
        res.m[2][0] = self.m[0][2];
        res.m[2][1] = self.m[1][2];
        res.m[2][2] = self.m[2][2];
        res.m[2][3] = self.m[3][2];
        res.m[3][0] = self.m[0][3];
        res.m[3][1] = self.m[1][3];
        res.m[3][2] = self.m[2][3];
        res.m[3][3] = self.m[3][3];
        return res;
    }

    pub fn scale(scaleVec3: Vec3) Mat4 {
        var res = Mat4.identity;
        res.m[0][0] = scaleVec3.x;
        res.m[1][1] = scaleVec3.y;
        res.m[2][2] = scaleVec3.z;
        return res;
    }

    pub fn persp(fov: f32, aspect: f32, near: f32, far: f32) Mat4 {
        var res = Mat4.identity;
        const t = math.tan(fov * (math.pi / 360.0));
        res.m[0][0] = 1.0 / t;
        res.m[1][1] = aspect / t;
        res.m[2][3] = -1.0;
        res.m[2][2] = (near + far) / (near - far);
        res.m[3][2] = (2.0 * near * far) / (near - far);
        res.m[3][3] = 0.0;
        return res;
    }

    pub fn ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        var res = Mat4.zero;
        res.m[0][0] = 2.0 / (right - left);
        res.m[1][1] = 2.0 / (top - bottom);
        res.m[2][2] = 2.0 / (near - far);
        res.m[3][3] = 1.0;

        res.m[3][0] = (left + right) / (left - right);
        res.m[3][1] = (bottom + top) / (bottom - top);
        res.m[3][2] = (near + far) / (near - far);

        return res;
    }

    pub fn lookat(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        var res = Mat4.zero;

        const f = center.sub(eye).norm();
        const s = f.cross(up).norm();
        const u = s.cross(f);

        res.m[0][0] = s.x;
        res.m[0][1] = u.x;
        res.m[0][2] = -f.x;

        res.m[1][0] = s.y;
        res.m[1][1] = u.y;
        res.m[1][2] = -f.y;

        res.m[2][0] = s.z;
        res.m[2][1] = u.z;
        res.m[2][2] = -f.z;

        res.m[3][0] = -s.dot(eye);
        res.m[3][1] = -u.dot(eye);
        res.m[3][2] = f.dot(eye);
        res.m[3][3] = 1.0;

        return res;
    }

    pub fn rotate(angle: f32, axis_unorm: Vec3) Mat4 {
        var res = Mat4.identity;

        const axis = axis_unorm.norm();
        const sin_theta = math.sin(radians(angle));
        const cos_theta = math.cos(radians(angle));
        const cos_value = 1.0 - cos_theta;

        res.m[0][0] = (axis.x * axis.x * cos_value) + cos_theta;
        res.m[0][1] = (axis.x * axis.y * cos_value) + (axis.z * sin_theta);
        res.m[0][2] = (axis.x * axis.z * cos_value) - (axis.y * sin_theta);
        res.m[1][0] = (axis.y * axis.x * cos_value) - (axis.z * sin_theta);
        res.m[1][1] = (axis.y * axis.y * cos_value) + cos_theta;
        res.m[1][2] = (axis.y * axis.z * cos_value) + (axis.x * sin_theta);
        res.m[2][0] = (axis.z * axis.x * cos_value) + (axis.y * sin_theta);
        res.m[2][1] = (axis.z * axis.y * cos_value) - (axis.x * sin_theta);
        res.m[2][2] = (axis.z * axis.z * cos_value) + cos_theta;

        return res;
    }

    /// Points in the direction of a vector
    pub fn direction(dir: Vec3, axis: Vec3) Mat4 {
        var res = Mat4.identity;
        const dir_norm = dir.norm();
        const axis_norm = axis.norm();

        var xaxis: Vec3 = axis_norm.cross(dir_norm);
        xaxis = xaxis.norm();

        var yaxis: Vec3 = dir_norm.cross(xaxis);
        yaxis = yaxis.norm();

        res.m[0][0] = xaxis.x;
        res.m[0][1] = yaxis.x;
        res.m[0][2] = dir_norm.x;
        res.m[1][0] = xaxis.y;
        res.m[1][1] = yaxis.y;
        res.m[1][2] = dir_norm.y;
        res.m[2][0] = xaxis.z;
        res.m[2][1] = yaxis.z;
        res.m[2][2] = dir_norm.z;

        return res.transpose();
    }

    /// Points in a direction, and flips if upside down. Useful for billboard sprites!
    pub fn billboard(dir: Vec3, up: Vec3) Mat4 {
        var rot_matrix = Mat4.direction(dir, up);

        // need to flip things if we're upside down
        if (up.y < 0 and dir.y == 0)
            rot_matrix = rot_matrix.mul(Mat4.scale(Vec3.new(1, -1, 1)));

        return rot_matrix;
    }

    pub fn translate(translation: Vec3) Mat4 {
        var res = Mat4.identity;
        res.m[3][0] = translation.x;
        res.m[3][1] = translation.y;
        res.m[3][2] = translation.z;
        return res;
    }

    pub const identity = Mat4{
        .m = [_][4]f32{ .{ 1.0, 0.0, 0.0, 0.0 }, .{ 0.0, 1.0, 0.0, 0.0 }, .{ 0.0, 0.0, 1.0, 0.0 }, .{ 0.0, 0.0, 0.0, 1.0 } },
    };

    pub const zero = Mat4{
        .m = [_][4]f32{ .{ 0.0, 0.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0, 0.0 } },
    };
};

test "Vec3.zero" {
    const v = Vec3.zero;
    assert(v.x == 0.0 and v.y == 0.0 and v.z == 0.0);
}

test "Vec3.new" {
    const v = Vec3.new(1.0, 2.0, 3.0);
    assert(v.x == 1.0 and v.y == 2.0 and v.z == 3.0);
}

test "Vec3.fromArray" {
    const v = Vec3.fromArray(.{ 1.0, 2.0, 3.0 });
    assert(v.x == 1.0 and v.y == 2.0 and v.z == 3.0);
}

test "Vec2.zero" {
    const v = Vec2.zero;
    assert(v.x == 0.0 and v.y == 0.0);
}

test "Vec2.fromArray" {
    const v = Vec2.fromArray(.{ 1.0, 2.0 });
    assert(v.x == 1.0 and v.y == 2.0);
}

test "Vec2.new" {
    const v = Vec2.new(1.0, 2.0);
    assert(v.x == 1.0 and v.y == 2.0);
}

test "Vec2.len" {
    const v = Vec2.new(2.0, 0.0).len();
    assert(v == 2.0);

    const v2 = Vec2.new(0.0, 1.0).len();
    assert(v2 == 1.0);
}

test "Vec2.norm" {
    const v = Vec2.new(2.0, 0.0).norm();
    assert(v.x == 1.0 and v.y == 0.0);
}

test "Mat4.ident" {
    const m = Mat4.identity;
    for (m.m, 0..) |row, y| {
        for (row, 0..) |val, x| {
            if (x == y) {
                assert(val == 1.0);
            } else {
                assert(val == 0.0);
            }
        }
    }
}

test "Mat4.mul" {
    const l = Mat4.identity;
    const r = Mat4.identity;
    const m = l.mul(r);
    for (m.m, 0..) |row, y| {
        for (row, 0..) |val, x| {
            if (x == y) {
                assert(val == 1.0);
            } else {
                assert(val == 0.0);
            }
        }
    }
}

fn eq(val: f32, cmp: f32) bool {
    const delta: f32 = 0.00001;
    return (val > (cmp - delta)) and (val < (cmp + delta));
}

test "Mat4.persp" {
    const m = Mat4.persp(60.0, 1.33333337, 0.01, 10.0);

    assert(eq(m.m[0][0], 1.73205));
    assert(eq(m.m[0][1], 0.0));
    assert(eq(m.m[0][2], 0.0));
    assert(eq(m.m[0][3], 0.0));

    assert(eq(m.m[1][0], 0.0));
    assert(eq(m.m[1][1], 2.30940));
    assert(eq(m.m[1][2], 0.0));
    assert(eq(m.m[1][3], 0.0));

    assert(eq(m.m[2][0], 0.0));
    assert(eq(m.m[2][1], 0.0));
    assert(eq(m.m[2][2], -1.00200));
    assert(eq(m.m[2][3], -1.0));

    assert(eq(m.m[3][0], 0.0));
    assert(eq(m.m[3][1], 0.0));
    assert(eq(m.m[3][2], -0.02002));
    assert(eq(m.m[3][3], 0.0));
}

test "Mat4.lookat" {
    const m = Mat4.lookat(.{ .x = 0.0, .y = 1.5, .z = 6.0 }, Vec3.zero, Vec3.up);

    assert(eq(m.m[0][0], 1.0));
    assert(eq(m.m[0][1], 0.0));
    assert(eq(m.m[0][2], 0.0));
    assert(eq(m.m[0][3], 0.0));

    assert(eq(m.m[1][0], 0.0));
    assert(eq(m.m[1][1], 0.97014));
    assert(eq(m.m[1][2], 0.24253));
    assert(eq(m.m[1][3], 0.0));

    assert(eq(m.m[2][0], 0.0));
    assert(eq(m.m[2][1], -0.24253));
    assert(eq(m.m[2][2], 0.97014));
    assert(eq(m.m[2][3], 0.0));

    assert(eq(m.m[3][0], 0.0));
    assert(eq(m.m[3][1], 0.0));
    assert(eq(m.m[3][2], -6.18465));
    assert(eq(m.m[3][3], 1.0));
}

test "Mat4.rotate" {
    const m = Mat4.rotate(2.0, .{ .x = 0.0, .y = 1.0, .z = 0.0 });

    assert(eq(m.m[0][0], 0.99939));
    assert(eq(m.m[0][1], 0.0));
    assert(eq(m.m[0][2], -0.03489));
    assert(eq(m.m[0][3], 0.0));

    assert(eq(m.m[1][0], 0.0));
    assert(eq(m.m[1][1], 1.0));
    assert(eq(m.m[1][2], 0.0));
    assert(eq(m.m[1][3], 0.0));

    assert(eq(m.m[2][0], 0.03489));
    assert(eq(m.m[2][1], 0.0));
    assert(eq(m.m[2][2], 0.99939));
    assert(eq(m.m[2][3], 0.0));

    assert(eq(m.m[3][0], 0.0));
    assert(eq(m.m[3][1], 0.0));
    assert(eq(m.m[3][2], 0.0));
    assert(eq(m.m[3][3], 1.0));
}

test "Vec3.mulMat4" {
    var l = Vec3{ .x = 1.0, .y = 2.0, .z = 3.0 };
    var r = Mat4.identity;
    var v = l.mulMat4(r);
    assert(v.x == 1.0);
    assert(v.y == 2.0);
    assert(v.z == 3.0);

    l = Vec3{ .x = 1.0, .y = 2.0, .z = 3.0 };
    r = Mat4.translate(Vec3{ .x = 2.0, .y = 0.0, .z = -3.0 });
    v = l.mulMat4(r);
    assert(v.x == 3.0);
    assert(v.y == 2.0);
    assert(v.z == 0.0);
}
