const std = @import("std");
const math = @import("../math.zig");
const debug = @import("../debug.zig");
const mem = @import("../mem.zig");

const Vec2 = math.Vec2;
const AnimationHashMap = std.StringHashMap(SpriteAnimation);

/// Keeps track of a sub region of a texture
/// Origin is in the upper left, x axis points right, and y axis points down
pub const TextureRegion = struct {
    u: f32 = 0,
    v: f32 = 0,
    u_2: f32 = 1.0,
    v_2: f32 = 1.0,

    /// Returns the default 0,0,1,1 region
    pub fn default() TextureRegion {
        return .{ .u = 0.0, .v = 0.0, .u_2 = 1.0, .v_2 = 1.0 };
    }

    /// Returns a region flipped vertically
    pub fn flipY(self: TextureRegion) TextureRegion {
        return .{ .u = self.u, .v = self.v_2, .u_2 = self.u_2, .v_2 = self.v };
    }

    /// Returns a region flipped horizontally
    pub fn flipX(self: TextureRegion) TextureRegion {
        return .{ .u = self.u_2, .v = self.v, .u_2 = self.u, .v_2 = self.v_2 };
    }

    /// Returns the size of this region
    pub fn getSize(self: TextureRegion) Vec2 {
        return Vec2.new(self.u_2 - self.u, self.v_2 - self.v);
    }

    /// Returns a region that has been offset by a given amount
    pub fn scroll(self: TextureRegion, amount: Vec2) TextureRegion {
        return .{ .u = self.u + amount.x, .v = self.v + amount.y, .u_2 = self.u_2 + amount.x, .v_2 = self.v_2 + amount.y };
    }
};

/// A single animation frame in an animated sprite sheeet
pub const AnimationFrame = struct {
    region: TextureRegion,
    size: Vec2 = Vec2.new(1, 1),
    sourceSize: Vec2 = Vec2.new(1, 1),
    offset: Vec2 = Vec2.zero,
    duration: f32 = 1.0,
};

/// An animation packed inside an animated sprite sheet
pub const SpriteAnimation = struct {
    frames: []AnimationFrame,

    /// Start playing this animation
    pub fn play(self: *const SpriteAnimation) PlayingAnimation {
        return PlayingAnimation.init(self.*);
    }
};

/// AnimatedSpriteSheets contain multiple named animations, each with a number of animation frames
pub const AnimatedSpriteSheet = struct {
    allocator: std.mem.Allocator,
    entries: AnimationHashMap = undefined,

    pub fn init(allocator: std.mem.Allocator) AnimatedSpriteSheet {
        return AnimatedSpriteSheet{
            .allocator = allocator,
            .entries = AnimationHashMap.init(allocator),
        };
    }

    pub fn deinit(self: *AnimatedSpriteSheet) void {
        // Cleanup SpriteAnimation entries
        var it = self.entries.valueIterator();
        while (it.next()) |sprite_anim_ptr| {
            self.allocator.free(sprite_anim_ptr.frames);
        }

        // Also cleanup the key names that we allocated
        var key_it = self.entries.keyIterator();
        while (key_it.next()) |key_ptr| {
            self.allocator.free(key_ptr.*);
        }

        self.entries.deinit();
    }

    /// Play the animation under the given animation name
    pub fn playAnimation(self: *AnimatedSpriteSheet, animation_name: [:0]const u8) ?PlayingAnimation {
        const entry = self.getAnimation(animation_name);
        if (entry == null)
            return null;

        return entry.?.play();
    }

    // Get the animation under the given animation name
    pub fn getAnimation(self: *AnimatedSpriteSheet, animation_name: [:0]const u8) ?SpriteAnimation {
        return self.entries.get(animation_name);
    }

    /// Get the first sprite under the given name
    pub fn getSprite(self: *AnimatedSpriteSheet, name: [:0]const u8) ?AnimationFrame {
        const entry = self.entries.get(name);
        if (entry == null)
            return null;

        if (entry.frames == 0)
            return null;

        return entry.frames[0];
    }

    pub fn playAnimationByIndex(self: *AnimatedSpriteSheet, idx: usize) ?PlayingAnimation {
        var value_iterator = self.entries.valueIterator();
        var cur_idx: usize = 0;
        while (value_iterator.next()) |val| {
            if (idx == cur_idx)
                return PlayingAnimation.init(val.*);

            cur_idx += 1;
        }
        return null;
    }

    /// Creates a series of animations: one per row in a grid where the columns are frames
    pub fn initFromGrid(rows: u32, cols: u32, anim_name_prefix: [:0]const u8) !AnimatedSpriteSheet {
        const allocator = mem.getAllocator();
        var sheet = AnimatedSpriteSheet.init(allocator);
        const rows_f: f32 = @floatFromInt(rows);
        const cols_f: f32 = @floatFromInt(cols);

        for (0..rows) |row_idx| {
            const row_idx_f: f32 = @floatFromInt(row_idx);
            const reg_v = row_idx_f / rows_f;
            const reg_v_2 = (row_idx_f + 1) / rows_f;

            var frames = try std.ArrayList(AnimationFrame).initCapacity(allocator, cols);
            errdefer frames.deinit();

            for (0..cols) |col_idx| {
                const col_idx_f: f32 = @floatFromInt(col_idx);
                const reg_u = col_idx_f / cols_f;
                const reg_u_2 = (col_idx_f + 1) / cols_f;

                try frames.append(AnimationFrame{ .region = TextureRegion{
                    .u = reg_u,
                    .v = reg_v,
                    .u_2 = reg_u_2,
                    .v_2 = reg_v_2,
                } });
            }

            // when converting an ArrayList to an owned slice, we don't need to deinit it
            const animation = SpriteAnimation{ .frames = try frames.toOwnedSlice() };

            var string_writer = std.ArrayList(u8).init(allocator);
            errdefer string_writer.deinit();

            try string_writer.writer().print("{s}{d}", .{ anim_name_prefix, row_idx });
            const anim_name = try string_writer.toOwnedSlice();

            try sheet.entries.put(anim_name, animation);
        }

        return sheet;
    }

    // pub fn fromAsepriteJsonFile(path: [:0]const u8) !SpriteSheet {
    //     const file = try std.io.readFileAlloc(allocator, path);
    //     defer allocator.free(file);
    //
    //     const sheet_data = std.json.parseFromSlice(SpriteAnimation, allocator, file, .{.allocate = .alloc_always});
    //
    //     var ret: SpriteSheet = SpriteSheet { .entries = AnimationHashMap.init(allocator) };
    //     ret.entries.put("first", sheet_data);
    //     return ret;
    // }
};

/// PlayingAnimation handles the state of playing a sprite animation
pub const PlayingAnimation = struct {
    animation: SpriteAnimation,
    frame_time: f64 = 0.0,
    frame: usize = 0,
    is_playing: bool = true,
    should_loop: bool = true,
    speed: f32 = 1.0,

    pub fn init(animation: SpriteAnimation) PlayingAnimation {
        return PlayingAnimation{
            .animation = animation,
        };
    }

    pub fn tick(self: *PlayingAnimation, delta_time: f32) void {
        if (!self.is_playing)
            return;

        if (self.frame >= self.animation.frames.len)
            return;

        self.frame_time += delta_time * self.speed;

        // check to see if we should be on the next frame
        if (self.frame_time > self.animation.frames[self.frame].duration) {
            // check to see if we should be on the next frame
            if (self.frame + 1 < self.animation.frames.len) {
                self.frame += 1;
                self.frame_time = 0.0;
            } else if (self.should_loop) {
                self.frame = 0;
                self.frame_time = 0.0;
            }
        }
    }

    pub fn play(self: *PlayingAnimation) void {
        self.is_playing = true;
    }

    pub fn setSpeed(self: *PlayingAnimation, speed: f32) void {
        self.speed = speed;
    }

    pub fn pause(self: *PlayingAnimation) void {
        self.is_playing = false;
    }

    pub fn reset(self: *PlayingAnimation) void {
        self.frame = 0;
        self.frame_time = 0.0;
    }

    pub fn loop(self: *PlayingAnimation, should_loop: bool) void {
        self.should_loop = should_loop;
    }

    pub fn getCurrentFrame(self: *PlayingAnimation) AnimationFrame {
        return self.animation.frames[self.frame];
    }

    pub fn isDonePlaying(self: *PlayingAnimation) bool {
        if (self.frame + 1 != self.animation.frames.len) {
            return false; // not on last frame
        }

        return self.frame_time >= self.animation.frames[self.frame].duration;
    }
};
