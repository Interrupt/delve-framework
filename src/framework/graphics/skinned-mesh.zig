const std = @import("std");
const graphics = @import("../platform/graphics.zig");
const debug = @import("../debug.zig");
const zmesh = @import("zmesh");
const math = @import("../math.zig");
const mem = @import("../mem.zig");
const colors = @import("../colors.zig");
const boundingbox = @import("../spatial/boundingbox.zig");
const mesh = @import("mesh.zig");

const Vertex = graphics.Vertex;
const Color = colors.Color;
const Rect = @import("../spatial/rect.zig").Rect;
const Frustum = @import("../spatial/frustum.zig").Frustum;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Mesh = mesh.Mesh;
const MeshConfig = mesh.MeshConfig;

pub fn getSkinnedShaderAttributes() []const graphics.ShaderAttribute {
    return mesh.getSkinnedShaderAttributes();
}

pub const PlayingAnimation = struct {
    anim_idx: usize = 0,
    time: f32 = 0.0,
    speed: f32 = 0.0,
    playing: bool = false,
    looping: bool = true,
    blend_alpha: f32 = 1.0,

    // calculated on play
    duration: f32 = 0.0,

    // calculated transforms of all joints in the animation (excluding skeleton)
    joint_transforms: ?std.ArrayList(AnimationTransform) = null,

    // calced transform matrices of all joints (including skeleton)
    joint_calced_matrices: ?std.ArrayList(math.Mat4) = null,

    pub fn isDonePlaying(self: *PlayingAnimation) bool {
        return self.time >= self.duration;
    }
};

const AnimationTransform = struct {
    translation: math.Vec3 = math.Vec3.zero,
    scale: math.Vec3 = math.Vec3.one,
    rotation: math.Quaternion = math.Quaternion.identity,

    // cache the calculated mat4
    calced_matrix: math.Mat4 = undefined,

    pub fn toMat4(self: *AnimationTransform) math.Mat4 {
        const mat = math.Mat4.recompose(self.translation, self.rotation, self.scale);

        // cache this calc to use later
        self.calced_matrix = mat;

        return mat;
    }
};

/// A skinned mesh is a mesh that can play animations based on joint data
pub const SkinnedMesh = struct {
    mesh: Mesh = undefined,

    joint_locations: [64]math.Mat4 = [_]math.Mat4{math.Mat4.identity} ** 64,
    playing_animation: PlayingAnimation = .{},

    pub fn initFromFile(allocator: std.mem.Allocator, filename: [:0]const u8, cfg: MeshConfig) ?SkinnedMesh {
        const loaded_mesh = Mesh.initFromFile(allocator, filename, cfg);
        if (loaded_mesh) |loaded| {
            return .{ .mesh = loaded };
        }
        return null;
    }

    pub fn deinit(self: *SkinnedMesh) void {
        self.mesh.deinit();
        if(self.playing_animation.joint_transforms) |transforms| {
            transforms.deinit();
        }
        if(self.playing_animation.joint_calced_matrices) |mats| {
            mats.deinit();
        }
    }

    /// Draw this mesh
    pub fn draw(self: *SkinnedMesh, proj_view_matrix: math.Mat4, model_matrix: math.Mat4) void {
        self.mesh.material.params.joints = &self.joint_locations;
        graphics.drawWithMaterial(&self.mesh.bindings, &self.mesh.material, proj_view_matrix, model_matrix);
    }

    /// Draw this mesh, using the specified material instead of the set one
    pub fn drawWithMaterial(self: *SkinnedMesh, material: *graphics.Material, proj_view_matrix: math.Mat4, model_matrix: math.Mat4) void {
        self.mesh.material.params.joints = &self.joint_locations;
        graphics.drawWithMaterial(&self.mesh.bindings, material, proj_view_matrix, model_matrix);
    }

    pub fn resetJoints(self: *SkinnedMesh) void {
        for (0..self.joint_locations.len) |i| {
            self.joint_locations[i] = math.Mat4.identity;
        }
    }

    pub fn getAnimationsCount(self: *SkinnedMesh) usize {
        return self.mesh.zmesh_data.?.animations_count;
    }

    pub fn playAnimation(self: *SkinnedMesh, anim_idx: usize, speed: f32, loop: bool) void {
        self.playing_animation.looping = loop;
        self.playing_animation.time = 0.0;
        self.playing_animation.speed = speed;

        if(self.mesh.zmesh_data == null)
            return;

        if (anim_idx >= self.mesh.zmesh_data.?.animations_count) {
            debug.log("warning: animation {} not found!", .{anim_idx});
            self.playing_animation.anim_idx = 0;
            self.playing_animation.playing = false;
            self.playing_animation.duration = 0;
            return;
        }

        if(self.playing_animation.joint_transforms == null) {
            self.playing_animation.joint_transforms = std.ArrayList(AnimationTransform).init(mem.getAllocator());
            self.playing_animation.joint_calced_matrices = std.ArrayList(math.Mat4).init(mem.getAllocator());

            // assume 64 joints for now!
            for(0..64) |_| {
                self.playing_animation.joint_transforms.?.append(.{}) catch { return; };
                self.playing_animation.joint_calced_matrices.?.append(math.Mat4.identity) catch { return; };
            }
        }

        self.playing_animation.anim_idx = anim_idx;
        self.playing_animation.playing = true;

        const animation = self.mesh.zmesh_data.?.animations.?[anim_idx];
        self.playing_animation.duration = zmesh.io.computeAnimationDuration(&animation);
    }

    pub fn playAnimationByName(self: *SkinnedMesh, anim_name: []const u8, speed: f32, loop: bool) void {
        // convert to a sentinel terminated pointer
        const anim_name_z = @as([*:0]u8, @constCast(@ptrCast(anim_name)));

        // Go find the animation whose name matches
        for (0..self.mesh.zmesh_data.?.animations_count) |i| {
            if (self.mesh.zmesh_data.?.animations.?[i].name) |name| {
                const result = std.mem.orderZ(u8, name, anim_name_z);
                if (result == .eq) {
                    // debug.log("Found animation index for {s} : {}", .{ anim_name, i });
                    self.playAnimation(i, speed, loop);
                    return;
                }
            }
        }

        debug.log("Could not find skined mesh animation to play: '{s}'", .{anim_name});
    }

    pub fn pauseAnimation(self: *SkinnedMesh) void {
        self.playing_animation.playing = false;
    }

    pub fn stopAnimation(self: *SkinnedMesh) void {
        self.playing_animation.playing = false;
        self.playing_animation.time = 0.0;
    }

    pub fn resumeAnimation(self: *SkinnedMesh) void {
        self.playing_animation.playing = true;
    }

    pub fn setAnimationSpeed(self: *SkinnedMesh, speed: f32) void {
        self.playing_animation.speed = speed;
    }

    pub fn updateAnimation(self: *SkinnedMesh, delta_time: f32) void {
        if (self.mesh.zmesh_data.?.skins == null or self.mesh.zmesh_data.?.animations == null)
            return;

        // todo: blend multiple animations
        var playing_animation = &self.playing_animation;
        if(self.playing_animation.joint_transforms == null)
            return;

        if (!playing_animation.playing)
            return;


        playing_animation.time += delta_time * playing_animation.speed;

        const animation = self.mesh.zmesh_data.?.animations.?[playing_animation.anim_idx];
        const animation_duration = playing_animation.duration;

        // loop if we need to!
        var t = playing_animation.time;
        if (playing_animation.looping) {
            t = @mod(t, animation_duration);
        }

        const nodes = self.mesh.zmesh_data.?.skins.?[0].joints;
        const nodes_count = self.mesh.zmesh_data.?.skins.?[0].joints_count;

        var local_transforms = playing_animation.joint_transforms.?.items;
        if(local_transforms.len == 0)
            return;

        for (0..nodes_count) |i| {
            const node = nodes[i];
            local_transforms[i] = .{
                .translation = math.Vec3.fromArray(node.translation),
                .scale = math.Vec3.fromArray(node.scale),
                .rotation = math.Quaternion.new(node.rotation[0], node.rotation[1], node.rotation[2], node.rotation[3]),
            };
        }

        for (0..animation.channels_count) |i| {
            const channel = animation.channels[i];
            const sampler = animation.samplers[i];

            var node_idx: usize = 0;
            var found_node = false;
            for (0..nodes_count) |ni| {
                if (nodes[ni] == channel.target_node.?) {
                    node_idx = ni;
                    found_node = true;
                    break;
                }
            }

            if (!found_node)
                continue;

            const alpha: f32 = playing_animation.blend_alpha;

            switch (channel.target_path) {
                .translation => {
                    const sampled_translation = self.sampleAnimation(math.Vec3, sampler, t);
                    if(alpha == 1.0) {
                        local_transforms[node_idx].translation = sampled_translation;
                    } else {
                        local_transforms[node_idx].translation = math.Vec3.lerp(local_transforms[node_idx].translation, sampled_translation, alpha);
                    }
                },
                .scale => {
                    const sampled_scale = self.sampleAnimation(math.Vec3, sampler, t);
                    if(alpha == 1.0) {
                        local_transforms[node_idx].scale = sampled_scale;
                    } else {
                        local_transforms[node_idx].scale = math.Vec3.lerp(local_transforms[node_idx].scale, sampled_scale, alpha);
                    }
                },
                .rotation => {
                    const sampled_quaternion = self.sampleAnimation(math.Quaternion, sampler, t);
                    if(alpha == 1.0) {
                        local_transforms[node_idx].rotation = sampled_quaternion;
                    } else {
                        local_transforms[node_idx].rotation = math.Quaternion.slerp(local_transforms[node_idx].rotation, sampled_quaternion, alpha);
                    }
                },
                else => {
                    // unhandled!
                },
            }
        }

        // update each joint location based on each node in the joint heirarchy
        for (0..nodes_count) |i| {
            var node = nodes[i];
            playing_animation.joint_calced_matrices.?.items[i] = local_transforms[i].toMat4();

            while (node.parent) |parent| : (node = parent) {
                var parent_idx: usize = 0;
                var found_node = false;

                for (0..nodes_count) |ni| {
                    if (nodes[ni] == parent) {
                        parent_idx = ni;
                        found_node = true;
                        break;
                    }
                }

                if (!found_node)
                    continue;

                const parent_transform = local_transforms[parent_idx].calced_matrix;
                playing_animation.joint_calced_matrices.?.items[i] = parent_transform.mul(playing_animation.joint_calced_matrices.?.items[i]);
            }
        }

        // apply the inverse bind matrices
        const inverse_bind_mat_data = zmesh.io.getAnimationSamplerData(self.mesh.zmesh_data.?.skins.?[0].inverse_bind_matrices.?);
        for (0..nodes_count) |i| {
            const inverse_mat = access(math.Mat4, inverse_bind_mat_data, i);
            self.joint_locations[i] = playing_animation.joint_calced_matrices.?.items[i].mul(inverse_mat);
        }
    }

    pub fn sampleAnimation(self: *SkinnedMesh, comptime T: type, sampler: zmesh.io.zcgltf.AnimationSampler, t: f32) T {
        _ = self;

        const samples = zmesh.io.getAnimationSamplerData(sampler.input);
        const data = zmesh.io.getAnimationSamplerData(sampler.output);

        switch (sampler.interpolation) {
            .step => {
                return access(T, data, stepInterpolation(samples, t));
            },
            .linear => {
                const r = linearInterpolation(samples, t);
                const v0 = access(T, data, r.prev_i);
                const v1 = access(T, data, r.next_i);

                if (T == math.Quaternion) {
                    return T.slerp(v0, v1, r.alpha);
                }

                return T.lerp(v0, v1, r.alpha);
            },
            .cubic_spline => {
                @panic("Cubicspline in animations not implemented!");
            },
        }
    }

    /// Returns the index of the last sample less than `t`.
    fn stepInterpolation(samples: []const f32, t: f32) usize {
        std.debug.assert(samples.len > 0);
        const S = struct {
            fn lessThan(_: void, lhs: f32, rhs: f32) bool {
                return lhs < rhs;
            }
        };
        const i = std.sort.lowerBound(f32, t, samples, {}, S.lessThan);
        return if (i > 0) i - 1 else 0;
    }

    /// Returns the indices of the samples around `t` and `alpha` to interpolate between those.
    fn linearInterpolation(samples: []const f32, t: f32) struct {
        prev_i: usize,
        next_i: usize,
        alpha: f32,
    } {
        const i = stepInterpolation(samples, t);
        if (i == samples.len - 1) return .{ .prev_i = i, .next_i = i, .alpha = 0 };

        const d = samples[i + 1] - samples[i];
        std.debug.assert(d > 0);
        const alpha = std.math.clamp((t - samples[i]) / d, 0, 1);

        return .{ .prev_i = i, .next_i = i + 1, .alpha = alpha };
    }

    pub fn access(comptime T: type, data: []const f32, i: usize) T {
        return switch (T) {
            Vec3 => Vec3.new(data[3 * i + 0], data[3 * i + 1], data[3 * i + 2]),
            math.Quaternion => math.Quaternion.new(data[4 * i + 0], data[4 * i + 1], data[4 * i + 2], data[4 * i + 3]),
            math.Mat4 => math.Mat4.fromSlice(data[16 * i ..][0..16]),
            else => @compileError("unexpected type"),
        };
    }
};
