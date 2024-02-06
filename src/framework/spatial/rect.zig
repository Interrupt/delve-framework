const std = @import("std");
const math = @import("../math.zig");

const Vec2 = math.Vec2;

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    /// Creates a new rectangle, where pos is the bottom-left
    pub fn new(pos: Vec2, size: Vec2) Rect {
        return Rect{
            .x = pos.x,
            .y = pos.y,
            .width = size.x,
            .height = size.y,
        };
    }

    /// Creates a new rectangle, where the position is zero
    pub fn fromSize(size: Vec2) Rect {
        return Rect{
            .x = 0.0,
            .y = 0.0,
            .width = size.x,
            .height = size.y,
        };
    }

    pub fn getPosition(self: *const Rect) Vec2 {
        return Vec2.new(self.x, self.y);
    }

    pub fn setPosition(self: *Rect, pos: Vec2) void {
        self.x = pos.x;
        self.y = pos.y;
    }

    pub fn getSize(self: *const Rect) Vec2 {
        return Vec2.new(self.width, self.height);
    }

    pub fn getCenter(self: *const Rect) Vec2 {
        return Vec2.new(self.x + self.width / 2.0, self.y + self.height / 2.0);
    }

    pub fn getBottomLeft(self: *const Rect) Vec2 {
        return Vec2.new(self.x, self.y);
    }

    pub fn getTopLeft(self: *const Rect) Vec2 {
        return Vec2.new(self.x, self.y + self.height);
    }

    pub fn getBottomRight(self: *const Rect) Vec2 {
        return Vec2.new(self.x + self.width, self.y);
    }

    pub fn getTopRight(self: *const Rect) Vec2 {
        return Vec2.new(self.x + self.width, self.y + self.height);
    }

    /// Check if this rectangle contains a point
    pub fn containsPoint(self: *const Rect, point: Vec2) bool {
        return (point.x >= self.x and
            point.y >= self.y and
            point.x < self.x + self.width and
            point.y < self.y + self.height);
    }

    /// Check if this rectangle overlaps another
    pub fn overlapsRect(self: *const Rect, other: Rect) bool {
        return (self.x + self.width > other.x and
            self.y + self.height > other.y and
            self.x < other.x + other.width and
            self.y < other.y + other.height);
    }

    /// Returns a centered version of this rectangle
    pub fn centered(self: *const Rect) Rect {
        return Rect.new(self.getPosition().sub(self.getSize().scale(0.5)), self.getSize());
    }

    /// Returns a box where only the X axis is centered
    pub fn centeredX(self: *const Rect) Rect {
        var pos = self.getPosition();
        pos.x -= self.width * 0.5;
        return Rect.new(pos, self.getSize());
    }

    /// Returns a box where only the Y axis is centered
    pub fn centeredY(self: *const Rect) Rect {
        var pos = self.getPosition();
        pos.y -= self.width * 0.5;
        return Rect.new(pos, self.getSize());
    }
};
