const std = @import("std");
const debug = @import("../debug.zig");
const math = @import("../math.zig");
const plane = @import("../spatial/plane.zig");
const assert = std.debug.assert;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Allocator = std.mem.Allocator;
const TokenIterator = std.mem.TokenIterator;
const Vec3 = math.Vec3;
const Plane = plane.Plane;

// From https://github.com/fabioarnold/3d-game/blob/master/src/QuakeMap.zig
// This is so cool!

const ErrorInfo = struct {
    line_number: usize,
};

const Property = struct {
    key: []const u8,
    value: []const u8,
};

pub const Face = struct {
    plane: Plane,
    texture_name: []const u8,
    u_axis: Vec3,
    v_axis: Vec3,
    shift_x: f32,
    shift_y: f32,
    rotation: f32,
    scale_x: f32,
    scale_y: f32,

    vertices: []Vec3,
};

pub const Entity = struct {
    classname: []const u8,
    spawnflags: u32,
    properties: std.ArrayList(Property),
    solids: std.ArrayList(Solid),

    fn init(allocator: Allocator) Entity {
        return .{
            .classname = &.{},
            .spawnflags = 0,
            .properties = std.ArrayList(Property).init(allocator),
            .solids = std.ArrayList(Solid).init(allocator),
        };
    }

    fn indexOfProperty(self: Entity, key: []const u8) ?usize {
        for (self.properties.items, 0..) |property, i| {
            if (std.mem.eql(u8, property.key, key)) {
                return i;
            }
        }
        return null;
    }

    pub fn hasProperty(self: Entity, key: []const u8) bool {
        return self.indexOfProperty(key) != null;
    }

    pub fn getStringProperty(self: Entity, key: []const u8) ![]const u8 {
        const i = self.indexOfProperty(key) orelse return error.NotFound;
        return self.properties.items[i].value;
    }

    pub fn getFloatProperty(self: Entity, key: []const u8) !f32 {
        const string = try self.getStringProperty(key);
        return try parseFloat(string);
    }

    pub fn getVec3Property(self: Entity, key: []const u8) !Vec3 {
        const string = try self.getStringProperty(key);
        var it = std.mem.tokenizeScalar(u8, string, ' ');

        var vec3: Vec3 = undefined;
        vec3.x = try parseFloat(it.next() orelse return error.ExpectedFloat);
        vec3.y = try parseFloat(it.next() orelse return error.ExpectedFloat);
        vec3.z = try parseFloat(it.next() orelse return error.ExpectedFloat);

        return vec3;
    }
};

pub const Solid = struct {
    faces: std.ArrayList(Face),

    fn init(allocator: Allocator) Solid {
        return .{ .faces = std.ArrayList(Face).init(allocator) };
    }

    fn computeVertices(self: *Solid) !void {
        const allocator = self.faces.allocator;
        var vertices = try std.ArrayListUnmanaged(Vec3).initCapacity(allocator, 32);
        var clipped = try std.ArrayListUnmanaged(Vec3).initCapacity(allocator, 32);

        defer vertices.deinit(allocator);
        defer clipped.deinit(allocator);

        for (self.faces.items, 0..) |*face, i| {
            const quad = makeQuadWithRadius(face.plane, 1000000.0);
            vertices.clearRetainingCapacity();
            vertices.appendSliceAssumeCapacity(&quad);

            // clip with other planes
            for (self.faces.items, 0..) |clip_face, j| {
                if (j == i) continue;
                clipped.clearRetainingCapacity();
                try clip(allocator, vertices, clip_face.plane, &clipped);
                if (clipped.items.len < 3) return error.DegenerateFace;
                std.mem.swap(std.ArrayListUnmanaged(Vec3), &vertices, &clipped);
            }

            face.vertices = try allocator.dupe(Vec3, vertices.items);
        }
    }

    fn clip(allocator: Allocator, vertices: std.ArrayListUnmanaged(Vec3), clip_plane: Plane, clipped: *std.ArrayListUnmanaged(Vec3)) !void {
        const epsilon = 0.0001;

        var distances = try std.ArrayListUnmanaged(f32).initCapacity(allocator, 32);
        defer distances.deinit(allocator);

        var cb: usize = 0;
        var cf: usize = 0;
        for (vertices.items) |vertex| {
            var distance = clip_plane.normal.dot(vertex) + clip_plane.d;
            if (distance < -epsilon) {
                cb += 1;
            } else if (distance > epsilon) {
                cf += 1;
            } else {
                distance = 0;
            }
            distances.appendAssumeCapacity(distance);
        }

        if (cb == 0 and cf == 0) {
            // co-planar
            return;
        } else if (cb == 0) {
            // all vertices in front
            return;
        } else if (cf == 0) {
            // all vertices in back;
            // keep
            clipped.appendSliceAssumeCapacity(vertices.items);
            return;
        }

        for (vertices.items, 0..) |s, i| {
            const j = (i + 1) % vertices.items.len;

            const e = vertices.items[j];
            const sd = distances.items[i];
            const ed = distances.items[j];
            if (sd <= 0) clipped.appendAssumeCapacity(s); // back

            if ((sd < 0 and ed > 0) or (ed < 0 and sd > 0)) {
                const t = sd / (sd - ed);
                var intersect = Vec3.lerp(s, e, t);

                // use plane's distance from origin, if plane's normal is a unit vector
                if (clip_plane.normal.x == 1) intersect.x = -clip_plane.d;
                if (clip_plane.normal.x == -1) intersect.x = clip_plane.d;
                if (clip_plane.normal.y == 1) intersect.y = -clip_plane.d;
                if (clip_plane.normal.y == -1) intersect.y = clip_plane.d;
                if (clip_plane.normal.z == 1) intersect.z = -clip_plane.d;
                if (clip_plane.normal.z == -1) intersect.z = clip_plane.d;
                clipped.appendAssumeCapacity(intersect);
            }
        }
    }
};

pub const QuakeMap = struct {
    worldspawn: Entity,
    entities: std.ArrayList(Entity),

    pub fn read(allocator: Allocator, data: []const u8, error_info: *ErrorInfo) !QuakeMap {
        var worldspawn: ?Entity = null;
        var entities = std.ArrayList(Entity).init(allocator);
        var iter = std.mem.tokenize(u8, data, "\r\n");

        error_info.line_number = 0;
        while (iter.next()) |line| {
            error_info.line_number += 1;
            switch (line[0]) {
                '/' => continue,
                '{' => {
                    const entity = try readEntity(allocator, &iter, error_info);
                    if (std.mem.eql(u8, entity.classname, "worldspawn")) {
                        worldspawn = entity;
                    } else {
                        try entities.append(entity);
                    }
                },
                else => return error.UnexpectedToken,
            }
        }
        return .{
            .worldspawn = worldspawn orelse return error.WorldSpawnNotFound,
            .entities = entities,
        };
    }

    fn readEntity(allocator: Allocator, iter: *TokenIterator(u8, .any), error_info: *ErrorInfo) !Entity {
        var entity = Entity.init(allocator);
        while (iter.next()) |line| {
            error_info.line_number += 1;
            switch (line[0]) {
                '/' => continue,
                '"' => {
                    const property = try readProperty(line);
                    if (std.mem.eql(u8, property.key, "classname")) {
                        entity.classname = property.value;
                    } else if (std.mem.eql(u8, property.key, "spawnflags")) {
                        entity.spawnflags = try std.fmt.parseInt(u32, property.value, 10);
                    } else {
                        try entity.properties.append(property);
                    }
                },
                '{' => try entity.solids.append(try readSolid(allocator, iter, error_info)),
                '}' => break,
                else => return error.UnexpectedToken,
            }
        }
        return entity;
    }

    fn readProperty(line: []const u8) !Property {
        var property: Property = undefined;
        var iter = std.mem.tokenizeScalar(u8, line, '"');
        property.key = try readSymbol(&iter);
        if (!std.mem.eql(u8, iter.next() orelse return error.UnexpectedEof, " ")) return error.ExpectedSpace;
        property.value = try readSymbol(&iter);
        return property;
    }

    fn readSolid(allocator: Allocator, iter: *TokenIterator(u8, .any), error_info: *ErrorInfo) !Solid {
        var solid = Solid.init(allocator);
        while (iter.next()) |line| {
            error_info.line_number += 1;
            switch (line[0]) {
                '/' => continue,
                '(' => try solid.faces.append(try readFace(line)),
                '}' => break,
                else => return error.UnexpectedToken,
            }
        }
        try solid.computeVertices();
        return solid;
    }

    fn readFace(line: []const u8) !Face {
        var face: Face = undefined;
        var iter = std.mem.tokenizeScalar(u8, line, ' ');
        const v0 = try readPoint(&iter);
        const v1 = try readPoint(&iter);
        const v2 = try readPoint(&iter);

        // map planes are clockwise, flip them around when computing the plane to get a counter-clockwise plane
        face.plane = Plane.initFromTriangle(v2, v1, v0);
        const direction = closestAxis(face.plane.normal);
        face.u_axis = if (direction.x == 1) Vec3.new(0, 1, 0) else Vec3.new(1, 0, 0);
        face.v_axis = if (direction.z == 1) Vec3.new(0, -1, 0) else Vec3.new(0, 0, -1);
        face.texture_name = try readSymbol(&iter);
        face.shift_x = try readDecimal(&iter);
        face.shift_y = try readDecimal(&iter);
        face.rotation = try readDecimal(&iter);
        face.scale_x = try readDecimal(&iter);
        face.scale_y = try readDecimal(&iter);
        return face;
    }

    fn readPoint(iter: *TokenIterator(u8, .scalar)) !Vec3 {
        var point: Vec3 = undefined;
        if (!std.mem.eql(u8, iter.next() orelse return error.UnexpectedEof, "(")) return error.ExpectedOpenParanthesis;
        point.x = try readDecimal(iter);
        point.y = try readDecimal(iter);
        point.z = try readDecimal(iter);
        if (!std.mem.eql(u8, iter.next() orelse return error.UnexpectedEof, ")")) return error.ExpectedCloseParanthesis;
        return point;
    }

    fn readDecimal(iter: *TokenIterator(u8, .scalar)) !f32 {
        const string = iter.next() orelse return error.UnexpectedEof;
        return try parseFloat(string);
    }

    fn readSymbol(iter: *TokenIterator(u8, .scalar)) ![]const u8 {
        return iter.next() orelse return &.{};
    }
};

fn makeQuadWithRadius(self: Plane, radius: f32) [4]Vec3 {
    const direction = closestAxis(self.normal);
    var up = if (direction.z == 1) Vec3.x_axis else Vec3.new(0, 0, -1);
    const upv = up.dot(self.normal);
    up = up.sub(self.normal.scale(upv)).norm();
    var right = up.cross(self.normal);

    up = up.scale(radius);
    right = right.scale(radius);

    const origin = self.normal.scale(-self.d);
    return .{
        origin.sub(right).sub(up),
        origin.add(right).sub(up),
        origin.add(right).add(up),
        origin.sub(right).add(up),
    };
}

fn closestAxis(v: Vec3) Vec3 {
    if (@fabs(v.x) >= @fabs(v.y) and @fabs(v.x) >= @fabs(v.z)) return Vec3.x_axis; // 1 0 0
    if (@fabs(v.y) >= @fabs(v.z)) return Vec3.up; // 0 1 0
    return Vec3.z_axis; // 0 0 1
}

// simpler float parsing function that runs quicker in debug
fn parseFloat(string: []const u8) !f32 {
    var signed: bool = false;
    var decimal_point: usize = string.len - 1;
    var decimal: f64 = 0;
    for (string, 0..) |c, i| {
        switch (c) {
            '-' => signed = true,
            '0'...'9' => {
                const digit: f64 = @floatFromInt(c - '0');
                decimal = 10 * decimal + digit;
            },
            '.' => decimal_point = i,
            else => return error.UnexpectedCharacter,
        }
    }
    if (signed) decimal *= -1;
    if (decimal_point < string.len - 1) {
        const denom = std.math.pow(f64, 10, @as(f64, @floatFromInt(string.len - 1 - decimal_point)));
        decimal /= denom;
    }
    return @floatCast(decimal);
}

test "QuakeMap.read" {
    // Test loading a very simple Quake map!
    // This is the example from https://quakewiki.org/wiki/Quake_Map_Format

    const test_map_file =
    \\{
    \\"spawnflags" "0"
    \\"classname" "worldspawn"
    \\"wad" "E:\q1maps\Q.wad"
    \\{
    \\( 256 64 16 ) ( 256 64 0 ) ( 256 0 16 ) mmetal1_2 0 0 0 1 1
    \\( 0 0 0 ) ( 0 64 0 ) ( 0 0 16 ) mmetal1_2 0 0 0 1 1
    \\( 64 256 16 ) ( 0 256 16 ) ( 64 256 0 ) mmetal1_2 0 0 0 1 1
    \\( 0 0 0 ) ( 0 0 16 ) ( 64 0 0 ) mmetal1_2 0 0 0 1 1
    \\( 64 64 0 ) ( 64 0 0 ) ( 0 64 0 ) mmetal1_2 0 0 0 1 1
    \\( 0 0 -64 ) ( 64 0 -64 ) ( 0 64 -64 ) mmetal1_2 0 0 0 1 1
    \\}
    \\}
    \\{
    \\"spawnflags" "0"
    \\"classname" "info_player_start"
    \\"origin" "32 32 24"
    \\}
    ;

    var allocator = gpa.allocator();

    var err: ErrorInfo = undefined;
    const map = try QuakeMap.read(allocator, test_map_file, &err);

    // Check to see if we have a world
    assert(std.mem.eql(u8, map.worldspawn.classname, "worldspawn"));
    assert(map.worldspawn.solids.items.len == 1);
    assert(map.worldspawn.solids.items[0].faces.items.len == 6);

    // Check to see that our one solid is a cube!
    for(0..6) |idx| {
        const face = map.worldspawn.solids.items[0].faces.items[idx];
        assert(face.vertices.len == 4);
    }

    // Check our first face to see if it looks accurate
    const first_face = map.worldspawn.solids.items[0].faces.items[0];
    assert(std.mem.eql(u8, first_face.texture_name, "mmetal1_2"));
    assert(first_face.shift_x == 0);
    assert(first_face.shift_y == 0);
    assert(first_face.rotation == 0);
    assert(first_face.scale_x == 1);
    assert(first_face.scale_y == 1);
    assert(std.meta.eql(first_face.vertices[0], Vec3.new(256, 0, 0)));
    assert(std.meta.eql(first_face.vertices[1], Vec3.new(256, 0, -64)));
    assert(std.meta.eql(first_face.vertices[2], Vec3.new(256, 256, -64)));
    assert(std.meta.eql(first_face.vertices[3], Vec3.new(256, 256, 0)));

    // Check our one entity
    assert(map.entities.items.len == 1);
    assert(std.mem.eql(u8, map.entities.items[0].classname, "info_player_start"));
    assert(map.entities.items[0].spawnflags == 0);
    assert(std.meta.eql(map.entities.items[0].getVec3Property("origin"), Vec3.new(32, 32, 24)));
}
