const std = @import("std");
const app = @import("../platform/app.zig");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const math = @import("../math.zig");
const input = @import("../platform/input.zig");

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

pub const Camera = struct {
    pos: Vec3 = Vec3.new(0, 0, 0),
    dir: Vec3 = Vec3.new(0, 0, 1),
    up: Vec3 = Vec3.up(),

    fov: f32 = 60.0,
    near: f32 = 0.001,
    far: f32 = 100.0,

    projection: Mat4 = Mat4.identity(),
    view: Mat4 = Mat4.identity(),

    aspect: f32 = undefined,
    viewport_width: f32 = undefined,
    viewport_height: f32 = undefined,

    pub fn init(fov: f32, near: f32, far: f32, up: Vec3) Camera {
        var cam = Camera{};
        cam.setViewport(@floatFromInt(app.getWidth()), @floatFromInt(app.getHeight()));
        cam.setPerspective(fov, near, far);
        cam.up = up;
        return cam;
    }

    pub fn setViewport(self: *Camera, width: f32, height: f32) void {
        self.aspect = width / height;
        self.viewport_width = width;
        self.viewport_height = height;
    }

    pub fn setPerspective(self: *Camera, fov: f32, near: f32, far: f32) void {
        self.fov = fov;
        self.near = near;
        self.far = far;
    }

    pub fn setPosition(self: *Camera, pos: Vec3) void {
        self.pos = pos;
    }

    pub fn getPosition(self: *Camera) Vec3 {
        return self.pos;
    }

    pub fn setDirection(self: *Camera, dir: Vec3) void {
        self.dir = dir.norm();
    }

    pub fn getDirection(self: *Camera) Vec3 {
        return self.dir;
    }

    pub fn getRightDirection(self: *Camera) Vec3 {
        return self.up.cross(self.dir);
    }

    pub fn moveForward(self: *Camera, amount: f32) void {
        self.pos = self.pos.add(self.dir.scale(-amount));
    }

    pub fn moveRight(self: *Camera, amount: f32) void {
        self.pos = self.pos.add(self.getRightDirection().scale(amount));
    }

    pub fn rotate(self: *Camera, angle: f32, axis: Vec3) void {
        const axis_norm = axis.norm();

        const half_angle = angle * 0.5;
        const angle_sin = std.math.sin(half_angle);
        const angle_cos = std.math.cos(half_angle);

        const w = axis_norm.scale(angle_sin);
        const wv = w.cross(self.dir);
        const wwv = w.cross(wv);

        const swv = wv.scale(angle_cos * 2.0);
        const swwv = wwv.scale(2.0);

        self.dir = self.dir.add(swv).add(swwv);
    }

    /// A simple FPS flying camera, for debugging
    pub fn runFlyCamera(self: *Camera, speed: f32, use_mouse: bool) void {
        const flyspeed = speed * 0.1;

        if(input.isKeyPressed(.W)) {
            self.moveForward(flyspeed);
        } else if(input.isKeyPressed(.S)) {
            self.moveForward(-flyspeed);
        }
        if(input.isKeyPressed(.A)) {
            self.moveRight(-flyspeed);
        } else if(input.isKeyPressed(.D)) {
            self.moveRight(flyspeed);
        }
        if(input.isKeyPressed(.LEFT)) {
            self.rotate(0.03, self.up);
        } else if(input.isKeyPressed(.RIGHT)) {
            self.rotate(-0.03, self.up);
        }
        if(input.isKeyPressed(.UP)) {
            self.rotate(0.03, self.getRightDirection());
        } else if(input.isKeyPressed(.DOWN)) {
            self.rotate(-0.03, self.getRightDirection());
        }

        if(!use_mouse)
            return;

        const mouseDelta = input.getMouseDelta();
        self.rotate(mouseDelta.x * -0.01, self.up);
        self.rotate(mouseDelta.y * -0.01, self.getRightDirection());
    }

    fn update(self: *Camera) void {
        self.projection = Mat4.persp(self.fov, self.aspect, self.near, self.far);
        self.view = Mat4.lookat(self.pos.add(self.dir), self.pos, self.up);
    }

    pub fn apply(self: *Camera) void {
        self.update();
        graphics.setViewState(self.view, self.projection);
    }
};
