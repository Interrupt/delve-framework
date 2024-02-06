const std = @import("std");
const math = @import("../math.zig");

const Vec2 = math.Vec2;

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    // positioning
    x_centered: bool = false,
    y_centered: bool = false,

    /// Creates a new rectangle, where pos is the bottom-left
    pub fn new(pos: Vec2, size: Vec2) Rect {
        return Rect{
            .x = pos.x,
            .y = pos.y,
            .width = size.x,
            .height = size.y,
        };
    }

    /// Creates a new rectangle, where pos is the center
    pub fn newCentered(pos: Vec2, size: Vec2) Rect {
        return Rect{
            .x = pos.x - (size.x * 0.5),
            .y = pos.y - (size.y * 0.5),
            .width = size.x,
            .height = size.y,
            .x_centered = true,
            .y_centered = true,
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

    /// Creates a new rectangle, where the center is zero
    pub fn fromSizeCentered(size: Vec2) Rect {
        return Rect{
            .x = -size.x * 0.5,
            .y = -size.y * 0.5,
            .width = size.x,
            .height = size.y,
            .x_centered = true,
            .y_centered = true,
        };
    }

    /// Gets the rect position, honoring the centering
    pub fn getPosition(self: *const Rect) Vec2 {
        var pos = Vec2.new(self.x, self.y);

        if (self.x_centered)
            pos.x += self.width * 0.5;
        if (self.y_centered)
            pos.y += self.height * 0.5;

        return pos;
    }

    /// Sets the rect position, honoring the centering
    pub fn setPosition(self: *Rect, pos: Vec2) void {
        self.x = pos.x;
        self.y = pos.y;

        if (self.x_centered)
            self.x -= self.width * 0.5;
        if (self.y_centered)
            self.y -= self.height * 0.5;
    }

    pub fn getSize(self: *const Rect) Vec2 {
        return Vec2.new(self.width, self.height);
    }

    pub fn getCenter(self: *const Rect) Vec2 {
        return Vec2.new(self.x + self.width * 0.5, self.y + self.height * 0.5);
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

    /// Returns a centered version of this rectangle, where the original position will be now the center
    pub fn centered(self: *const Rect) Rect {
        var pos = Vec2.new(self.x, self.y);

        if (!self.x_centered)
            pos.x -= self.width * 0.5;
        if (!self.y_centered)
            pos.y -= self.height * 0.5;

        var rect = Rect.new(pos, self.getSize());
        rect.x_centered = true;
        rect.y_centered = true;
        return rect;
    }

    /// Returns a box where only the X axis is centered
    pub fn centeredX(self: *const Rect) Rect {
        if (self.x_centered)
            return self.*;

        var pos = Vec2.new(self.x, self.y);
        pos.x -= self.width * 0.5;
        var rect = Rect.new(pos, self.getSize());
        rect.x_centered = true;
        return rect;
    }

    /// Returns a box where only the Y axis is centered
    pub fn centeredY(self: *const Rect) Rect {
        if (self.y_centered)
            return self.*;

        var pos = Vec2.new(self.x, self.y);
        pos.y -= self.width * 0.5;
        var rect = Rect.new(pos, self.getSize());
        rect.y_centered = true;
        return rect;
    }

    pub fn scale(self: *const Rect, scale_by: f32) Rect {
        var pos = Vec2.new(self.x, self.y);
        var size = self.getSize().scale(scale_by);

        var rect = Rect.new(pos, size);

        // If we were a centered rect, do the offset as well
        if (self.x_centered)
            rect.x -= rect.width * 0.5;
        if (self.y_centered)
            rect.y -= rect.height * 0.5;

        rect.x_centered = self.x_centered;
        rect.y_centered = self.y_centered;

        return rect;
    }

    pub fn translate(self: *const Rect, move_by: Vec2) Rect {
        // make a copy!
        var rect = self.*;
        rect.x += move_by.x;
        rect.y += move_by.y;
        return rect;
    }
};
