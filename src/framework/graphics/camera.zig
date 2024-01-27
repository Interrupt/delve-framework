const std = @import("std");
const app = @import("../platform/app.zig");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const math = @import("../math.zig");
const input = @import("../platform/input.zig");

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

/// Basic camera system with support for first and third person modes
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

    third_person: bool = false,
    boom_arm_length: f32 = 10.0,

    mouselook_scale: f32 = 0.35,

    _viewport_width: f32 = undefined,
    _viewport_height: f32 = undefined,

    /// Create a new camera
    pub fn init(fov: f32, near: f32, far: f32, up: Vec3) Camera {
        var cam = Camera{};
        cam.setViewport(@floatFromInt(app.getWidth()), @floatFromInt(app.getHeight()));
        cam.fov = fov;
        cam.near = near;
        cam.far = far;
        cam.up = up;
        return cam;
    }

    pub fn initThirdPerson(fov: f32, near: f32, far: f32, cam_distance: f32, up: Vec3) Camera {
        var cam = init(fov, near, far, up);
        cam.third_person = true;
        cam.boom_arm_length = cam_distance;
        return cam;
    }

    /// Set our aspect ratio based on the given width and height
    pub fn setViewport(self: *Camera, width: f32, height: f32) void {
        self.aspect = width / height;
        self._viewport_width = width;
        self._viewport_height = height;
    }

    /// Get the direction 90 degrees to the right of our direction
    pub fn getRightDirection(self: *Camera) Vec3 {
        return self.up.cross(self.direction);
    }

    /// Move the camera along its direction
    pub fn moveForward(self: *Camera, amount: f32) void {
        self.position = self.position.add(self.direction.scale(-amount));
    }

    /// Move the camera along its right direction
    pub fn moveRight(self: *Camera, amount: f32) void {
        self.position = self.position.add(self.getRightDirection().scale(amount));
    }

    /// Rotate the camera around an axis
    pub fn rotate(self: *Camera, angle: f32, axis: Vec3) void {
        self.direction = self.direction.rotate(angle, axis);
    }

    /// Rotate the camera around its up axis
    pub fn yaw(self: *Camera, angle: f32) void {
        self.rotate(angle, self.up);
    }

    /// Rotate the camera around its right direction
    pub fn pitch(self: *Camera, angle: f32) void {
        self.rotate(angle, self.getRightDirection());
    }

    /// A simple FPS flying camera, for examples and debugging
    pub fn runFlyCamera(self: *Camera, move_speed: f32, turn_speed: f32, use_mouselook: bool) void {
        if (input.isKeyPressed(.W)) {
            self.moveForward(move_speed);
        } else if (input.isKeyPressed(.S)) {
            self.moveForward(-move_speed);
        }
        if (input.isKeyPressed(.A)) {
            self.moveRight(-move_speed);
        } else if (input.isKeyPressed(.D)) {
            self.moveRight(move_speed);
        }
        if (input.isKeyPressed(.LEFT)) {
            self.yaw(turn_speed);
        } else if (input.isKeyPressed(.RIGHT)) {
            self.yaw(-turn_speed);
        }
        if (input.isKeyPressed(.UP)) {
            self.pitch(turn_speed);
        } else if (input.isKeyPressed(.DOWN)) {
            self.pitch(-turn_speed);
        }

        if (!use_mouselook)
            return;

        const mouse_delta = input.getMouseDelta();
        const mouse_mod: f32 = -self.mouselook_scale;
        self.yaw(mouse_delta.x * mouse_mod * turn_speed);
        self.pitch(mouse_delta.y * mouse_mod * turn_speed);
    }

    fn update(self: *Camera) void {
        self.projection = Mat4.persp(self.fov, self.aspect, self.near, self.far);

        // third person camera
        if (self.third_person) {
            self.view = Mat4.lookat(self.position.add(self.direction.scale(self.boom_arm_length)), self.position, self.up);
            return;
        }

        // first person camera
        self.view = Mat4.lookat(self.position, self.position.sub(self.direction), self.up);
    }

    /// Applies projection and view, returns a projection * view matrix
    pub fn getProjView(self: *Camera) Mat4 {
        self.update();
        return self.projection.mul(self.view);
    }
};
