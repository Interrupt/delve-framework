const std = @import("std");
const math = @import("../math.zig");
const debug = @import("../debug.zig");

const Vec2 = math.Vec2;

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    // positioning
    origin: ?Vec2 = null,

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
            .origin = pos,
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

    /// Adds an origin to a rectangle. Default is bottom left.
    pub fn withOrigin(self: *const Rect, origin: Vec2) Rect {
        var rect = self.*;
        rect.origin = origin;

        var diff = if (self.origin != null) self.origin.?.sub(origin) else origin.scale(-1);
        return rect.translate(diff);
    }

    /// Creates a new rectangle, where the center is zero
    pub fn fromSizeCentered(size: Vec2) Rect {
        return Rect{
            .x = -size.x * 0.5,
            .y = -size.y * 0.5,
            .width = size.x,
            .height = size.y,
            .origin = Vec2.zero(),
        };
    }

    /// Gets the rect position, which will be the origin if given or the bottom left if not
    pub fn getPosition(self: *const Rect) Vec2 {
        if (self.origin != null)
            return self.origin.?;

        return Vec2.new(self.x, self.y);
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
        var center = self.getCenter();
        return self.withOrigin(center);
    }

    /// Returns a box where only the X axis is centered
    pub fn centeredX(self: *const Rect) Rect {
        var center = self.getCenter();
        var pos = self.getPosition();
        center.y = pos.y;

        return self.withOrigin(center);
    }

    /// Returns a box where only the Y axis is centered
    pub fn centeredY(self: *const Rect) Rect {
        var center = self.getCenter();
        var pos = self.getPosition();
        center.x = pos.x;

        return self.withOrigin(center);
    }

    pub fn scale(self: *const Rect, scale_by: f32) Rect {
        var rect = self.*;

        rect.width *= scale_by;
        rect.height *= scale_by;
        rect.x *= scale_by;
        rect.y *= scale_by;

        // cancel out translation - but origin stays the same
        if (self.origin) |origin| {
            rect.x += origin.x - (origin.x * scale_by);
            rect.y += origin.y - (origin.y * scale_by);
        }

        return rect;
    }

    pub fn translate(self: *const Rect, move_by: Vec2) Rect {
        // make a copy!
        var rect = self.*;
        rect.x += move_by.x;
        rect.y += move_by.y;

        // origin also may need to move
        if (rect.origin != null) {
            rect.origin.?.x += move_by.x;
            rect.origin.?.y += move_by.y;
        }

        return rect;
    }
};
