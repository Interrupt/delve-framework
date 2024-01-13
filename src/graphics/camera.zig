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
    position: Vec3 = Vec3.new(0, 0, 0),
    direction: Vec3 = Vec3.new(0, 0, 1),
    up: Vec3 = Vec3.up(),

    fov: f32 = 60.0,
    near: f32 = 0.001,
    far: f32 = 100.0,

    projection: Mat4 = Mat4.identity(),
    view: Mat4 = Mat4.identity(),
    aspect: f32 = undefined,

    _viewport_width: f32 = undefined,
    _viewport_height: f32 = undefined,

    pub fn init(fov: f32, near: f32, far: f32, up: Vec3) Camera {
        var cam = Camera{};
        cam.setViewport(@floatFromInt(app.getWidth()), @floatFromInt(app.getHeight()));
        cam.setPerspective(fov, near, far);
        cam.up = up;
        return cam;
    }

    pub fn setViewport(self: *Camera, width: f32, height: f32) void {
        self.aspect = width / height;
        self._viewport_width = width;
        self._viewport_height = height;
    }

    pub fn setPerspective(self: *Camera, fov: f32, near: f32, far: f32) void {
        self.fov = fov;
        self.near = near;
        self.far = far;
    }

    pub fn getRightDirection(self: *Camera) Vec3 {
        return self.up.cross(self.direction);
    }

    pub fn moveForward(self: *Camera, amount: f32) void {
        self.position = self.position.add(self.direction.scale(-amount));
    }

    pub fn moveRight(self: *Camera, amount: f32) void {
        self.position = self.position.add(self.getRightDirection().scale(amount));
    }

    pub fn rotate(self: *Camera, angle: f32, axis: Vec3) void {
        self.direction = self.direction.rotate(angle, axis);
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
        self.view = Mat4.lookat(self.position.add(self.direction), self.position, self.up);
    }

    pub fn apply(self: *Camera) void {
        self.update();
        graphics.setViewState(self.view, self.projection);
    }
};
