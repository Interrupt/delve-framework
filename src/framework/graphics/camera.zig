const std = @import("std");
const app = @import("../platform/app.zig");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const math = @import("../math.zig");
const input = @import("../platform/input.zig");
const frustum = @import("../spatial/frustum.zig");

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

pub const ViewMode = enum(i32) {
    FIRST_PERSON,
    THIRD_PERSON,
};

pub const MoveMode = enum(i32) {
    FLY,
    WALK,
};

const angle_to_radians: f32 = 57.29578;

/// Basic camera system with support for first and third person modes
pub const Camera = struct {
    position: Vec3 = Vec3.zero,
    direction: Vec3 = Vec3.z_axis.scale(-1),
    up: Vec3 = Vec3.up,
    right: Vec3 = Vec3.x_axis,

    yaw_angle: f32 = 0.0,
    pitch_angle: f32 = 0.0,
    roll_angle: f32 = 0.0,

    fov: f32 = 60.0,
    near: f32 = 0.001,
    far: f32 = 100.0,

    projection: Mat4 = Mat4.identity,
    view: Mat4 = Mat4.identity,
    aspect: f32 = undefined,

    view_mode: ViewMode = .FIRST_PERSON,
    move_mode: MoveMode = .FLY,
    boom_arm_length: f32 = 10.0,

    mouselook_scale: f32 = 0.35,

    limit_pitch: bool = true,
    pitch_max: f32 = 89.999,
    pitch_min: f32 = -89.999,

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
        cam.view_mode = .THIRD_PERSON;
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
        return self.right;
    }

    /// Move the camera along its direction
    pub fn moveForward(self: *Camera, amount: f32) void {
        // fly mode
        if (self.move_mode == .FLY) {
            self.position = self.position.add(self.direction.scale(amount));
            return;
        }

        // walk mode, ignores pitch!
        var dir = self.direction;
        dir.y = 0.0;
        dir = dir.norm();

        self.position = self.position.add(dir.scale(amount));
    }

    /// Move the camera along its right direction
    pub fn moveRight(self: *Camera, amount: f32) void {
        self.position = self.position.add(self.getRightDirection().scale(amount));
    }

    pub fn updateDirection(self: *Camera) void {
        var dir = math.Vec3.z_axis.scale(-1);
        dir = dir.rotate(self.pitch_angle, math.Vec3.x_axis);
        dir = dir.rotate(self.yaw_angle, math.Vec3.y_axis);
        self.direction = dir;

        var up = math.Vec3.up;
        up = up.rotate(self.pitch_angle, math.Vec3.x_axis);
        up = up.rotate(self.yaw_angle, math.Vec3.y_axis);
        self.up = up;

        var right = math.Vec3.x_axis;
        right = right.rotate(self.pitch_angle, math.Vec3.x_axis);
        right = right.rotate(self.yaw_angle, math.Vec3.y_axis);
        self.right = right;
    }

    /// Rotate the camera left and right
    pub fn yaw(self: *Camera, angle: f32) void {
        self.yaw_angle += angle;
        self.updateDirection();
    }

    /// Rotate the camera up and down
    pub fn pitch(self: *Camera, angle: f32) void {
        self.pitch_angle += angle;

        if (self.limit_pitch)
            self.pitch_angle = std.math.clamp(self.pitch_angle, self.pitch_min, self.pitch_max);

        self.updateDirection();
    }

    /// Rotate the camera around its view direction
    pub fn roll(self: *Camera, angle: f32) void {
        self.roll_angle += angle;
    }

    /// Set this camera's yaw to a set angle
    pub fn setYaw(self: *Camera, angle: f32) void {
        self.yaw_angle = angle;
        self.updateDirection();
    }

    /// Set this camera's pitch to a set angle
    pub fn setPitch(self: *Camera, angle: f32) void {
        self.pitch_angle = angle;
        self.updateDirection();
    }

    /// Set this camera's roll to a set angle
    pub fn setRoll(self: *Camera, angle: f32) void {
        self.roll_angle = angle;
        self.updateDirection();
    }

    /// A simple FPS flying camera, for examples and debugging
    pub fn runSimpleCamera(self: *Camera, move_speed: f32, turn_speed: f32, use_mouselook: bool) void {
        // handle the viewport changing size
        const width: f32 = @floatFromInt(app.getWidth());
        const height: f32 = @floatFromInt(app.getHeight());
        if (width != self._viewport_width or height != self._viewport_height) {
            self.setViewport(width, height);
        }

        // handle input
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

    /// Sets our view matrices from the current camera state, returns the current matrices
    pub fn update(self: *Camera) graphics.CameraMatrices {
        self.projection = Mat4.persp(self.fov, self.aspect, self.near, self.far);

        // third person camera
        if (self.view_mode == .THIRD_PERSON) {
            self.view = Mat4.lookat(self.position.sub(self.direction.scale(self.boom_arm_length)), self.position, self.up);
            return self.getViewMatrices();
        }

        // first person camera
        self.view = Mat4.lookat(Vec3.zero, Vec3.zero.add(self.direction), self.up);
        self.view = self.view.mul(Mat4.rotate(-self.roll_angle, self.direction));
        self.view = self.view.mul(Mat4.translate(self.position.scale(-1)));

        return self.getViewMatrices();
    }

    /// Returns the current view matrices
    pub fn getViewMatrices(self: *Camera) graphics.CameraMatrices {
        return .{ .view = self.view, .proj = self.projection };
    }

    /// Applies projection and view, returns a projection * view matrix
    pub fn getProjView(self: *Camera) Mat4 {
        _ = self.update();
        return self.projection.mul(self.view);
    }

    pub fn getViewFrustum(self: *Camera) frustum.Frustum {
        return frustum.Frustum.init(self.getProjView());
    }

    pub fn getPosition(self: *Camera) Vec3 {
        // returns the end position, including the boom arm
        return self.position.add(self.direction.scale(self.boom_arm_length));
    }
};
