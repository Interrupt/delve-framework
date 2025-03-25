//------------------------------------------------------------------------------
//  math.zig
//
//  minimal vector math helper functions, just the stuff needed for
//  the sokol-samples
//
//  Ported from HandmadeMath.h, and some Quaternion functions from kooparse/zalgebra
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

    pub fn toArray(self: Vec2) [2]f32 {
        return [_]f32{ self.x, self.y };
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

    pub fn toArray(self: Vec3) [3]f32 {
        return [_]f32{ self.x, self.y, self.z };
    }

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn lerp(start: Vec3, end: Vec3, alpha: f32) Vec3 {
        const t = std.math.clamp(alpha, 0.0, 1.0);
        return start.add((end.sub(start)).scale(t));
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

    pub fn toVec4(v: *const Vec3, w: f32) Vec4 {
        return Vec4.new(v.x, v.y, v.z, w);
    }

    pub const zero = Vec3.new(0.0, 0.0, 0.0);
    pub const one = Vec3.new(1.0, 1.0, 1.0);
    pub const x_axis = Vec3.new(1.0, 0.0, 0.0);
    pub const y_axis = Vec3.new(0.0, 1.0, 0.0);
    pub const z_axis = Vec3.new(0.0, 0.0, 1.0);
    pub const up = Vec3.new(0.0, 1.0, 0.0);
    pub const down = Vec3.new(0.0, -1.0, 0.0);
};

pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn fromArray(val: [4]f32) Vec4 {
        return Vec4{ .x = val[0], .y = val[1], .z = val[2], .w = val[3] };
    }

    pub fn toArray(self: Vec4) [4]f32 {
        return [_]f32{ self.x, self.y, self.z, self.w };
    }

    pub fn new(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return Vec4{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn add(left: *const Vec4, right: Vec4) Vec3 {
        return Vec4{ .x = left.x + right.x, .y = left.y + right.y, .z = left.z + right.z, .w = left.w + right.w };
    }

    pub fn sub(left: *const Vec4, right: Vec4) Vec3 {
        return Vec4{ .x = left.x - right.x, .y = left.y - right.y, .z = left.z - right.z, .w = left.w - right.w };
    }

    pub fn scale(v: *const Vec4, s: f32) Vec4 {
        return Vec4{ .x = v.x * s, .y = v.y * s, .z = v.z * s, .w = v.w * s };
    }

    pub fn mul(left: *const Vec4, right: Vec4) Vec4 {
        return Vec4{ .x = left.x * right.x, .y = left.y * right.y, .z = left.z * right.z, .w = left.w * right.w };
    }

    pub fn projMat4(v: *const Vec4, self: Mat4) Vec4 {
        const inv_w = 1.0 / (v.x * self.m[0][3] + v.y * self.m[1][3] + v.z * self.m[2][3] + self.m[3][3]);

        const x = (self.m[0][0] * v.x) + (self.m[1][0] * v.y) + (self.m[2][0] * v.z) + (self.m[3][0] * v.w);
        const y = (self.m[0][1] * v.x) + (self.m[1][1] * v.y) + (self.m[2][1] * v.z) + (self.m[3][1] * v.w);
        const z = (self.m[0][2] * v.x) + (self.m[1][2] * v.y) + (self.m[2][2] * v.z) + (self.m[3][2] * v.w);
        const w = (self.m[0][3] * v.x) + (self.m[1][3] * v.y) + (self.m[2][3] * v.z) + (self.m[3][3] * v.w);

        return Vec4.new(x * inv_w, y * inv_w, z * inv_w, w);
    }

    pub fn mulMat4(left: *const Vec4, right: Mat4) Vec4 {
        var res = Vec4.zero;
        res.x += left.x * right.m[0][0];
        res.y += left.x * right.m[0][1];
        res.z += left.x * right.m[0][2];
        res.w += left.x * right.m[0][3];
        res.x += left.y * right.m[1][0];
        res.y += left.y * right.m[1][1];
        res.z += left.y * right.m[1][2];
        res.w += left.y * right.m[1][3];
        res.x += left.z * right.m[2][0];
        res.y += left.z * right.m[2][1];
        res.z += left.z * right.m[2][2];
        res.w += left.z * right.m[2][3];
        res.x += left.w * right.m[3][0];
        res.y += left.w * right.m[3][1];
        res.z += left.w * right.m[3][2];
        res.w += left.w * right.m[3][3];
        return res;
    }

    pub fn len(self: *const Vec4) f32 {
        const v = Vec3.new(self.x, self.y, self.z);
        return math.sqrt(v.dot(Vec3.new(v.x, v.y, v.z)));
    }

    pub fn norm(v: *const Vec4) Vec4 {
        const l = Vec4.len(v);
        if (l != 0.0) {
            return Vec4{ .x = v.x / l, .y = v.y / l, .z = v.z / l, .w = v.w / l };
        } else {
            return Vec4.new(0, 0, 0, 0);
        }
    }

    pub fn toVec3(v: *const Vec4) Vec3 {
        return Vec3.new(v.x, v.y, v.z);
    }

    pub const zero = Vec4.new(0.0, 0.0, 0.0, 1.0);
};

// Mat4: 4x4 matrix stored in row-major
pub const Mat4 = extern struct {
    m: [4][4]f32,

    pub fn toArray(self: *const Mat4) [4][4]f32 {
        return self.m;
    }

    pub fn fromSlice(slice: *const [16]f32) Mat4 {
        var res = Mat4.zero;
        res.m[0][0] = slice[0];
        res.m[0][1] = slice[1];
        res.m[0][2] = slice[2];
        res.m[0][3] = slice[3];
        res.m[1][0] = slice[4];
        res.m[1][1] = slice[5];
        res.m[1][2] = slice[6];
        res.m[1][3] = slice[7];
        res.m[2][0] = slice[8];
        res.m[2][1] = slice[9];
        res.m[2][2] = slice[10];
        res.m[2][3] = slice[11];
        res.m[3][0] = slice[12];
        res.m[3][1] = slice[13];
        res.m[3][2] = slice[14];
        res.m[3][3] = slice[15];
        return res;
    }

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

    // Create a Mat4 out of a translation, rotation, and scale
    pub fn recompose(translation: Vec3, rotation: Quaternion, scalar: Vec3) Mat4 {
        var r = rotation.toMat4();

        r.m[0][0] *= scalar.x;
        r.m[0][1] *= scalar.x;
        r.m[0][2] *= scalar.x;
        r.m[1][0] *= scalar.y;
        r.m[1][1] *= scalar.y;
        r.m[1][2] *= scalar.y;
        r.m[2][0] *= scalar.z;
        r.m[2][1] *= scalar.z;
        r.m[2][2] *= scalar.z;

        r.m[3][0] = translation.x;
        r.m[3][1] = translation.y;
        r.m[3][2] = translation.z;

        return r;
    }

    pub fn detsubs(self: *const Mat4) [12]f32 {
        return .{
            self.m[0][0] * self.m[1][1] - self.m[1][0] * self.m[0][1],
            self.m[0][0] * self.m[1][2] - self.m[1][0] * self.m[0][2],
            self.m[0][0] * self.m[1][3] - self.m[1][0] * self.m[0][3],
            self.m[0][1] * self.m[1][2] - self.m[1][1] * self.m[0][2],
            self.m[0][1] * self.m[1][3] - self.m[1][1] * self.m[0][3],
            self.m[0][2] * self.m[1][3] - self.m[1][2] * self.m[0][3],

            self.m[2][0] * self.m[3][1] - self.m[3][0] * self.m[2][1],
            self.m[2][0] * self.m[3][2] - self.m[3][0] * self.m[2][2],
            self.m[2][0] * self.m[3][3] - self.m[3][0] * self.m[2][3],
            self.m[2][1] * self.m[3][2] - self.m[3][1] * self.m[2][2],
            self.m[2][1] * self.m[3][3] - self.m[3][1] * self.m[2][3],
            self.m[2][2] * self.m[3][3] - self.m[3][2] * self.m[2][3],
        };
    }

    /// Inverts a matrix
    pub fn invert(self: *const Mat4) Mat4 {
        var inv_mat: Mat4 = undefined;

        const s = detsubs(self);

        const determ = 1 / (s[0] * s[11] - s[1] * s[10] + s[2] * s[9] + s[3] * s[8] - s[4] * s[7] + s[5] * s[6]);

        inv_mat.m[0][0] = determ * (self.m[1][1] * s[11] - self.m[1][2] * s[10] + self.m[1][3] * s[9]);
        inv_mat.m[0][1] = determ * -(self.m[0][1] * s[11] - self.m[0][2] * s[10] + self.m[0][3] * s[9]);
        inv_mat.m[0][2] = determ * (self.m[3][1] * s[5] - self.m[3][2] * s[4] + self.m[3][3] * s[3]);
        inv_mat.m[0][3] = determ * -(self.m[2][1] * s[5] - self.m[2][2] * s[4] + self.m[2][3] * s[3]);

        inv_mat.m[1][0] = determ * -(self.m[1][0] * s[11] - self.m[1][2] * s[8] + self.m[1][3] * s[7]);
        inv_mat.m[1][1] = determ * (self.m[0][0] * s[11] - self.m[0][2] * s[8] + self.m[0][3] * s[7]);
        inv_mat.m[1][2] = determ * -(self.m[3][0] * s[5] - self.m[3][2] * s[2] + self.m[3][3] * s[1]);
        inv_mat.m[1][3] = determ * (self.m[2][0] * s[5] - self.m[2][2] * s[2] + self.m[2][3] * s[1]);

        inv_mat.m[2][0] = determ * (self.m[1][0] * s[10] - self.m[1][1] * s[8] + self.m[1][3] * s[6]);
        inv_mat.m[2][1] = determ * -(self.m[0][0] * s[10] - self.m[0][1] * s[8] + self.m[0][3] * s[6]);
        inv_mat.m[2][2] = determ * (self.m[3][0] * s[4] - self.m[3][1] * s[2] + self.m[3][3] * s[0]);
        inv_mat.m[2][3] = determ * -(self.m[2][0] * s[4] - self.m[2][1] * s[2] + self.m[2][3] * s[0]);

        inv_mat.m[3][0] = determ * -(self.m[1][0] * s[9] - self.m[1][1] * s[7] + self.m[1][2] * s[6]);
        inv_mat.m[3][1] = determ * (self.m[0][0] * s[9] - self.m[0][1] * s[7] + self.m[0][2] * s[6]);
        inv_mat.m[3][2] = determ * -(self.m[3][0] * s[3] - self.m[3][1] * s[1] + self.m[3][2] * s[0]);
        inv_mat.m[3][3] = determ * (self.m[2][0] * s[3] - self.m[2][1] * s[1] + self.m[2][2] * s[0]);

        return inv_mat;
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

pub const Quaternion = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const zero = Quaternion{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 };
    pub const identity = Quaternion{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 };

    pub fn new(x: f32, y: f32, z: f32, w: f32) Quaternion {
        return Quaternion{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn norm(self: *const Quaternion) Quaternion {
        const l = self.length();
        if (l == 0) {
            return self.*;
        }

        return Quaternion.new(
            self.x / l,
            self.y / l,
            self.z / l,
            self.w / l,
        );
    }

    pub fn length(self: *const Quaternion) f32 {
        return @sqrt(self.dot(self.*));
    }

    pub fn add(left: Quaternion, right: Quaternion) Quaternion {
        return Quaternion.new(left.x + right.x, left.y + right.y, left.z + right.z, left.w + right.w);
    }

    pub fn sub(left: Quaternion, right: Quaternion) Quaternion {
        return Quaternion.new(left.x - right.x, left.y - right.y, left.z - right.z, left.w - right.w);
    }

    pub fn mul(left: Quaternion, right: Quaternion) Quaternion {
        const x = (left.x * right.w) + (left.y * right.z) - (left.z * right.y) + (left.w * right.x);
        const y = (-left.x * right.z) + (left.y * right.w) + (left.z * right.x) + (left.w * right.y);
        const z = (left.x * right.y) - (left.y * right.x) + (left.z * right.w) + (left.w * right.z);
        const w = (-left.x * right.x) - (left.y * right.y) - (left.z * right.z) + (left.w * right.w);
        return Quaternion.new(x, y, z, w);
    }

    pub fn scale(left: Quaternion, right: f32) Quaternion {
        return Quaternion.new(left.x * right, left.y * right, left.z * right, left.w * right);
    }

    pub fn div(left: Quaternion, right: f32) Quaternion {
        return Quaternion.new(left.x / right, left.y / right, left.z / right, left.w / right);
    }

    pub fn mix(left: Quaternion, mix_left: f32, right: Quaternion, mix_right: f32) Quaternion {
        var result = Quaternion.zero;

        result.x = left.x * mix_left + right.x * mix_right;
        result.y = left.y * mix_left + right.y * mix_right;
        result.z = left.z * mix_left + right.z * mix_right;
        result.w = left.w * mix_left + right.w * mix_right;

        return result;
    }

    pub fn dot(left: *const Quaternion, right: Quaternion) f32 {
        return ((left.x * right.x) + (left.z * right.z)) + ((left.y * right.y) + (left.w * right.w));
    }

    pub fn inv(self: *const Quaternion) Quaternion {
        const result = Quaternion.new(-self.x, -self.y, -self.z, self.w);
        return result.div(self.dot(self));
    }

    pub fn lerp(left: Quaternion, right: Quaternion, alpha: f32) Quaternion {
        const result = Quaternion.mix(left, 1.0 - alpha, right, alpha);
        return result.norm();
    }

    pub fn slerp(left: Quaternion, right: Quaternion, alpha: f32) Quaternion {
        var cos_theta = left.dot(right);
        var new_right = right;

        var result: Quaternion = undefined;

        if (cos_theta < 0.0) { // Take shortest path on Hyper-sphere
            cos_theta = -cos_theta;
            new_right = Quaternion.new(-right.x, -right.y, -right.z, -right.w);
        }

        // Use Normalized Linear interpolation when vectors are roughly not L.I.
        if (cos_theta > 0.9995) {
            result = Quaternion.lerp(left, right, alpha);
        } else {
            const angle: f32 = std.math.cos(cos_theta);
            const mix_left: f32 = std.math.sin((1.0 - alpha) * angle);
            const mix_right: f32 = std.math.sin(alpha * angle);

            result = Quaternion.mix(left, mix_left, right, mix_right).norm();
        }

        return result;
    }

    pub fn toMat4(self: *const Quaternion) Mat4 {
        var result: Mat4 = Mat4.identity;

        const normalized = self.norm();

        const xx = normalized.x * normalized.x;
        const yy = normalized.y * normalized.y;
        const zz = normalized.z * normalized.z;
        const xy = normalized.x * normalized.y;
        const xz = normalized.x * normalized.z;
        const yz = normalized.y * normalized.z;
        const wx = normalized.w * normalized.x;
        const wy = normalized.w * normalized.y;
        const wz = normalized.w * normalized.z;

        result.m[0][0] = 1.0 - 2.0 * (yy + zz);
        result.m[0][1] = 2.0 * (xy + wz);
        result.m[0][2] = 2.0 * (xz - wy);
        result.m[0][3] = 0.0;

        result.m[1][0] = 2.0 * (xy - wz);
        result.m[1][1] = 1.0 - 2.0 * (xx + zz);
        result.m[1][2] = 2.0 * (yz + wx);
        result.m[1][3] = 0.0;

        result.m[2][0] = 2.0 * (xz + wy);
        result.m[2][1] = 2.0 * (yz - wx);
        result.m[2][2] = 1.0 - 2.0 * (xx + yy);
        result.m[2][3] = 0.0;

        result.m[3][0] = 0.0;
        result.m[3][1] = 0.0;
        result.m[3][2] = 0.0;
        result.m[3][3] = 1.0;

        return result;
    }

    pub fn fromMat4(mat: Mat4) Quaternion {
        var result: Quaternion = undefined;
        var t: f32 = undefined;

        if (mat.m[2][2] < 0) {
            if (mat.m[0][0] > mat.m[1][1]) {
                t = 1 + mat.m[0][0] - mat.m[1][1] - mat.m[2][2];
                result = Quaternion.new(
                    t,
                    mat.m[0][1] + mat.m[1][0],
                    mat.m[2][0] + mat.m[0][2],
                    mat.m[1][2] - mat.m[2][1],
                );
            } else {
                t = 1 - mat.m[0][0] + mat.m[1][1] - mat.m[2][2];
                result = Quaternion.new(
                    mat.m[0][1] + mat.m[1][0],
                    t,
                    mat.m[1][2] + mat.m[2][1],
                    mat.m[2][0] - mat.m[0][2],
                );
            }
        } else {
            if (mat.m[0][0] < -mat.m[1][1]) {
                t = 1 - mat.m[0][0] - mat.m[1][1] + mat.m[2][2];
                result = Quaternion.new(
                    mat.m[2][0] + mat.m[0][2],
                    mat.m[1][2] + mat.m[2][1],
                    t,
                    mat.m[0][1] - mat.m[1][0],
                );
            } else {
                t = 1 + mat.m[0][0] + mat.m[1][1] + mat.m[2][2];
                result = Quaternion.new(
                    mat.m[1][2] - mat.m[2][1],
                    mat.m[2][0] - mat.m[0][2],
                    mat.m[0][1] - mat.m[1][0],
                    t,
                );
            }
        }

        return result.scale(0.5 / @sqrt(t));
    }

    pub fn fromAxisAndAngle(angle: f32, axis: Vec3) Quaternion {
        const angle_rad = radians(angle);

        var result = Quaternion.zero;
        const axis_normalized: Vec3 = axis.norm();
        const sin_of_rotation = std.math.sin(angle_rad / 2.0);

        const r = axis_normalized.scale(sin_of_rotation);

        result.x = r.x;
        result.y = r.y;
        result.z = r.z;
        result.w = std.math.cos(angle_rad / 2.0);

        return result;
    }

    pub fn rotateVec3(left: Quaternion, right: Vec3) Vec3 {
        const quat_vec = Vec3.new(left.x, left.y, left.z);
        const t = quat_vec.cross(right).scale(2.0);
        return right.add(t.scale(left.w).add(quat_vec.cross(t)));
    }

    pub fn fromAxisAndAngleLH(angle: f32, axis: Vec3) Quaternion {
        return Quaternion.fromAxisAngle(-angle, axis);
    }
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

test "Mat4.invert" {
    const m = Mat4.persp(60.0, 1.33333337, 0.01, 10.0);
    const inverted = m.invert();

    const before = Vec3.new(1, 10, -1);
    const transformed = before.mulMat4(m);
    const after = transformed.mulMat4(inverted);

    // std.debug.print("\n\nBefore: {}, After: {}\n", .{before, after});
    assert(std.meta.eql(before, after));
}
