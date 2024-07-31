const std = @import("std");
const debug = @import("../debug.zig");
const math = @import("../math.zig");
const plane = @import("../spatial/plane.zig");
const boundingbox = @import("../spatial/boundingbox.zig");
const rays = @import("../spatial/rays.zig");
const mesh = @import("../graphics/mesh.zig");
const colors = @import("../colors.zig");
const graphics = @import("../platform/graphics.zig");
const assert = std.debug.assert;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Allocator = std.mem.Allocator;
const TokenIterator = std.mem.TokenIterator;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Plane = plane.Plane;
const Mesh = mesh.Mesh;
const BoundingBox = boundingbox.BoundingBox;
const Ray = rays.Ray;

// From https://github.com/fabioarnold/3d-game/blob/master/src/QuakeMap.zig
// This is so cool!

pub const ErrorInfo = struct {
    line_number: usize,
};

pub const QuakeMapHit = struct {
    loc: Vec3,
    plane: Plane,
};

pub const Property = struct {
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
    uv_direction: Vec3, // cache Closest Axis
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
    bounds: BoundingBox = undefined,

    fn init(allocator: Allocator) Solid {
        return .{ .faces = std.ArrayList(Face).init(allocator) };
    }

    fn computeVertices(self: *Solid) !void {
        const allocator = self.faces.allocator;
        var vertices = try std.ArrayListUnmanaged(Vec3).initCapacity(allocator, 32);
        var clipped = try std.ArrayListUnmanaged(Vec3).initCapacity(allocator, 32);

        defer vertices.deinit(allocator);
        defer clipped.deinit(allocator);

        // build a bounding box along the way too
        var solid_bounds: BoundingBox = undefined;

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

            // try to fix up cracks along seams
            const round_amount = 10.0;
            for (face.vertices, 0..) |vertex, j| {
                face.vertices[j].x = std.math.round(vertex.x * round_amount) / round_amount;
                face.vertices[j].y = std.math.round(vertex.y * round_amount) / round_amount;
                face.vertices[j].z = std.math.round(vertex.z * round_amount) / round_amount;
            }

            // create a bounding box out of these vertices
            const face_bounds: BoundingBox = BoundingBox.initFromPositions(face.vertices);
            if (i == 0) {
                solid_bounds = face_bounds;
                continue;
            }

            // expand our solid's bounding box by the new face bounds
            solid_bounds.min = Vec3.min(solid_bounds.min, face_bounds.min);
            solid_bounds.max = Vec3.max(solid_bounds.max, face_bounds.max);
        }

        self.bounds = solid_bounds;
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

    pub fn checkCollision(self: *const Solid, point: math.Vec3) bool {
        for (self.faces.items) |*face| {
            if (face.plane.testPoint(point) == .FRONT)
                return false;
        }
        return true;
    }

    // Get our planes expanded by the Minkowski sum of the bounding box
    pub fn getExpandedPlanes(self: *const Solid, size: math.Vec3) [24]?Plane {
        var expanded_planes = [_]?Plane{null} ** 24;
        var plane_count: usize = 0;

        if (self.faces.items.len == 0)
            return expanded_planes;

        for (self.faces.items) |*face| {
            var expand_dist: f32 = 0;

            // x_axis
            const x_d = face.plane.normal.dot(math.Vec3.x_axis);
            if (x_d > 0) expand_dist += -x_d * size.x;

            const x_d_n = face.plane.normal.dot(math.Vec3.x_axis.scale(-1));
            if (x_d_n > 0) expand_dist += -x_d_n * size.x;

            // y_axis
            const y_d = face.plane.normal.dot(math.Vec3.y_axis);
            if (y_d > 0) expand_dist += -y_d * size.y;

            const y_d_n = face.plane.normal.dot(math.Vec3.y_axis.scale(-1));
            if (y_d_n > 0) expand_dist += -y_d_n * size.y;

            // z_axis
            const z_d = face.plane.normal.dot(math.Vec3.z_axis);
            if (z_d > 0) expand_dist += -z_d * size.z;

            const z_d_n = face.plane.normal.dot(math.Vec3.z_axis.scale(-1));
            if (z_d_n > 0) expand_dist += -z_d_n * size.z;

            var expandedface = face.plane;
            expandedface.d += expand_dist;

            expanded_planes[plane_count] = expandedface;
            plane_count += 1;
        }

        // Make the Minkowski sum of both bounding boxes
        var solid_bounds = self.bounds;
        solid_bounds.min.x -= size.x;
        solid_bounds.min.y -= size.y;
        solid_bounds.min.z -= size.z;

        solid_bounds.max.x += size.x;
        solid_bounds.max.y += size.y;
        solid_bounds.max.z += size.z;

        // Can use the sum as our bevel planes
        const bevel_planes = solid_bounds.getPlanes();
        for (bevel_planes) |p| {
            expanded_planes[plane_count] = p;
            plane_count += 1;
        }

        return expanded_planes;
    }

    pub fn checkBoundingBoxCollision(self: *const Solid, bounds: BoundingBox) bool {
        const x_size = (bounds.max.x - bounds.min.x) * 0.5;
        const y_size = (bounds.max.y - bounds.min.y) * 0.5;
        const z_size = (bounds.max.z - bounds.min.z) * 0.5;
        const point = bounds.center;

        const expanded_planes = self.getExpandedPlanes(Vec3.new(x_size, y_size, z_size));
        for (expanded_planes) |ep| {
            if (ep) |p| {
                if (p.testPoint(point) == .FRONT)
                    return false;
            }
        }

        return true;
    }

    pub fn checkBoundingBoxCollisionWithVelocity(self: *const Solid, bounds: BoundingBox, velocity: Vec3) ?QuakeMapHit {
        var worldhit: ?QuakeMapHit = null;

        const size = bounds.max.sub(bounds.min).scale(0.5);
        const planes = self.getExpandedPlanes(size);

        const point = bounds.center;
        const next = point.add(velocity);

        if (planes.len == 0)
            return null;

        for (0..planes.len) |idx| {
            const ep = planes[idx];
            if (ep) |p| {
                // must start in front but end in back
                if (p.testPoint(point) == .BACK)
                    continue;
                if (p.testPoint(next) == .FRONT)
                    continue;

                const hit = p.intersectLine(point, next);
                if (hit) |h| {
                    var didhit = true;
                    for (0..planes.len) |h_idx| {
                        if (idx == h_idx)
                            continue;

                        // check that this hit point is behind the other clip planes
                        if (planes[h_idx]) |pp| {
                            if (pp.testPoint(h) == .FRONT) {
                                didhit = false;
                                break;
                            }
                        }
                    }

                    if (didhit) {
                        worldhit = .{
                            .loc = h,
                            .plane = p,
                        };

                        // convex, so should only have one collision
                        break;
                    }
                }
            }
        }

        return worldhit;
    }

    pub fn checkLineCollision(self: *const Solid, start: Vec3, end: Vec3) ?QuakeMapHit {
        var worldhit: ?QuakeMapHit = null;

        if (self.faces.items.len == 0)
            return null;

        for (0..self.faces.items.len) |idx| {
            const p = self.faces.items[idx].plane;
            // must start in front and end in back
            if (p.testPoint(start) == .BACK)
                continue;
            if (p.testPoint(end) == .FRONT)
                continue;

            const hit = p.intersectLine(start, end);

            if (hit) |h| {
                var didhit = true;
                for (0..self.faces.items.len) |h_idx| {
                    if (idx == h_idx)
                        continue;

                    // check that this hit point is behind the other clip planes
                    const pp = self.faces.items[h_idx].plane;
                    if (pp.testPoint(h) == .FRONT) {
                        didhit = false;
                        break;
                    }
                }

                if (didhit) {
                    worldhit = .{
                        .loc = h,
                        .plane = p,
                    };

                    // convex, so should only have one collision
                    break;
                }
            }
        }

        return worldhit;
    }

    pub fn checkRayCollision(self: *const Solid, ray: Ray) ?QuakeMapHit {
        var worldhit: ?QuakeMapHit = null;

        if (self.faces.items.len == 0)
            return null;

        for (0..self.faces.items.len) |idx| {
            const p = self.faces.items[idx].plane;

            // must start in front!
            if (p.testPoint(ray.pos) == .BACK)
                continue;

            const hit = ray.intersectPlane(p, true);

            if (hit) |h| {
                var didhit = true;
                for (0..self.faces.items.len) |h_idx| {
                    if (idx == h_idx)
                        continue;

                    // check that this hit point is behind the other clip planes
                    const pp = self.faces.items[h_idx].plane;
                    if (pp.testPoint(h.hit_pos) == .FRONT) {
                        didhit = false;
                        break;
                    }
                }

                if (didhit) {
                    worldhit = .{
                        .loc = h.hit_pos,
                        .plane = p,
                    };

                    // convex, so should only have one collision
                    break;
                }
            }
        }

        return worldhit;
    }
};

pub const QuakeMaterial = struct {
    material: graphics.Material,
    tex_size_x: i32 = 32,
    tex_size_y: i32 = 32,
};

pub const QuakeMap = struct {
    worldspawn: Entity,
    entities: std.ArrayList(Entity),
    map_transform: math.Mat4,

    pub fn read(allocator: Allocator, data: []const u8, transform: math.Mat4, error_info: *ErrorInfo) !QuakeMap {
        var worldspawn: ?Entity = null;
        var entities = std.ArrayList(Entity).init(allocator);
        var iter = std.mem.tokenize(u8, data, "\r\n");

        error_info.line_number = 0;
        while (iter.next()) |line| {
            error_info.line_number += 1;
            switch (line[0]) {
                '/' => continue,
                '{' => {
                    const entity = try readEntity(allocator, &iter, transform, error_info);
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
            .map_transform = transform,
        };
    }

    fn readEntity(allocator: Allocator, iter: *TokenIterator(u8, .any), transform: math.Mat4, error_info: *ErrorInfo) !Entity {
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
                '{' => try entity.solids.append(try readSolid(allocator, iter, transform, error_info)),
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

    fn readSolid(allocator: Allocator, iter: *TokenIterator(u8, .any), transform: math.Mat4, error_info: *ErrorInfo) !Solid {
        var solid = Solid.init(allocator);
        while (iter.next()) |line| {
            error_info.line_number += 1;
            switch (line[0]) {
                '/' => continue,
                '(' => try solid.faces.append(try readFace(line, transform)),
                '}' => break,
                else => return error.UnexpectedToken,
            }
        }
        try solid.computeVertices();
        return solid;
    }

    fn readFace(line: []const u8, transform: math.Mat4) !Face {
        var face: Face = undefined;
        var iter = std.mem.tokenizeScalar(u8, line, ' ');
        const v0 = try readPoint(&iter, math.Mat4.identity);
        const v1 = try readPoint(&iter, math.Mat4.identity);
        const v2 = try readPoint(&iter, math.Mat4.identity);

        // Get UV scaling from the transform matrix. Assume uniform scaling.
        var scale = transform.m[0][0] * transform.m[0][0] + transform.m[0][1] * transform.m[0][1] + transform.m[0][2] * transform.m[0][2];
        scale = std.math.sqrt(scale);

        // map planes are clockwise, flip them around when computing the plane to get a counter-clockwise plane
        face.plane = Plane.initFromTriangle(v2, v1, v0);
        const direction = closestAxis(face.plane.normal);
        face.uv_direction = direction.mulMat4(transform).norm();
        face.u_axis = if (direction.x == 1) Vec3.new(0, 1, 0).mulMat4(transform).norm() else Vec3.new(1, 0, 0).mulMat4(transform).norm();
        face.v_axis = if (direction.z == 1) Vec3.new(0, -1, 0).mulMat4(transform).norm() else Vec3.new(0, 0, -1).mulMat4(transform).norm();
        face.texture_name = try readSymbol(&iter);
        face.shift_x = try readDecimal(&iter);
        face.shift_y = try readDecimal(&iter);
        face.rotation = try readDecimal(&iter);
        face.scale_x = try readDecimal(&iter) * scale;
        face.scale_y = try readDecimal(&iter) * scale;
        face.plane = face.plane.mulMat4(transform);
        return face;
    }

    fn readPoint(iter: *TokenIterator(u8, .scalar), transform: math.Mat4) !Vec3 {
        var point: Vec3 = undefined;
        if (!std.mem.eql(u8, iter.next() orelse return error.UnexpectedEof, "(")) return error.ExpectedOpenParanthesis;
        point.x = try readDecimal(iter);
        point.y = try readDecimal(iter);
        point.z = try readDecimal(iter);

        point = point.mulMat4(transform);

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

    /// Builds meshes for the map, bucketed by materials
    pub fn buildWorldMeshes(self: *const QuakeMap, allocator: Allocator, transform: math.Mat4, materials: *std.StringHashMap(QuakeMaterial), fallback_material: ?*QuakeMaterial) !std.ArrayList(Mesh) {

        // Make our mesh buckets - we'll make a new mesh per material!
        var mesh_builders = std.StringHashMap(mesh.MeshBuilder).init(allocator);

        // Add our solids
        for (self.worldspawn.solids.items) |solid| {
            try addSolidToMeshBuilders(allocator, &mesh_builders, solid, materials, transform);
        }

        // We're ready to build all of our mesh builders now!
        var meshes = std.ArrayList(mesh.Mesh).init(allocator);
        try buildMeshes(&mesh_builders, materials, fallback_material, &meshes);
        return meshes;
    }

    /// Builds meshes for all entity solids - in a real scenario, you'll want to do this yourself
    pub fn buildEntityMeshes(self: *const QuakeMap, allocator: Allocator, transform: math.Mat4, materials: *std.StringHashMap(QuakeMaterial), fallback_material: ?*QuakeMaterial) !std.ArrayList(Mesh) {

        // Make our mesh buckets - we'll make a new mesh per material!
        var mesh_builders = std.StringHashMap(mesh.MeshBuilder).init(allocator);

        // Add the solids for all of the entities
        for (self.entities.items) |entity| {
            for (entity.solids.items) |solid| {
                try addSolidToMeshBuilders(allocator, &mesh_builders, solid, materials, transform);
            }
        }

        // We're ready to build all of our mesh builders now!
        var meshes = std.ArrayList(mesh.Mesh).init(allocator);
        try buildMeshes(&mesh_builders, materials, fallback_material, &meshes);
        return meshes;
    }

    /// builds meshes out of a map of MeshBuilders, and adds them to an ArrayList
    pub fn buildMeshes(builders: *const std.StringHashMap(mesh.MeshBuilder), materials: *std.StringHashMap(QuakeMaterial), fallback_material: ?*QuakeMaterial, out_meshes: *std.ArrayList(mesh.Mesh)) !void {
        var it = builders.iterator();
        while (it.next()) |builder| {
            const b = builder.value_ptr;
            if (b.indices.items.len == 0)
                continue;

            var found_material = materials.getPtr(builder.key_ptr.*);
            if (found_material == null) {
                try out_meshes.append(b.buildMesh(&fallback_material.?.material));
            } else {
                try out_meshes.append(b.buildMesh(&found_material.?.material));
            }
        }
    }

    /// Adds all of the faces of a solid to a list of MeshBuilders, based on the face's texture name
    pub fn addSolidToMeshBuilders(allocator: std.mem.Allocator, builders: *std.StringHashMap(mesh.MeshBuilder), solid: Solid, materials: *std.StringHashMap(QuakeMaterial), transform: math.Mat4) !void {
        for (solid.faces.items) |face| {
            const found_builder = builders.getPtr(face.texture_name);
            var builder: *mesh.MeshBuilder = undefined;

            if (found_builder) |b| {
                builder = b;
            } else {
                // This is ugly - is there a better way?
                try builders.put(face.texture_name, mesh.MeshBuilder.init(allocator));
                builder = builders.getPtr(face.texture_name).?;
            }

            const mat = materials.get(face.texture_name);
            try addFaceToMeshBuilder(builder, face, mat, transform);
        }
    }

    pub fn addFaceToMeshBuilder(builder: *mesh.MeshBuilder, face: Face, material: ?QuakeMaterial, transform: math.Mat4) !void {
        var u_axis: Vec3 = undefined;
        var v_axis: Vec3 = undefined;
        calculateRotatedUV(face, &u_axis, &v_axis);

        var tex_size_x: f32 = 32;
        var tex_size_y: f32 = 32;
        if (material) |mat| {
            tex_size_x = @floatFromInt(mat.tex_size_x);
            tex_size_y = @floatFromInt(mat.tex_size_y);
        }

        for (0..face.vertices.len - 2) |i| {
            const pos_0 = Vec3.new(face.vertices[0].x, face.vertices[0].y, face.vertices[0].z);
            const uv_0 = Vec2.new(
                (u_axis.dot(pos_0) + face.shift_x) / tex_size_x,
                (v_axis.dot(pos_0) + face.shift_y) / tex_size_y,
            );

            const pos_1 = Vec3.new(face.vertices[i + 1].x, face.vertices[i + 1].y, face.vertices[i + 1].z);
            const uv_1 = Vec2.new(
                (u_axis.dot(pos_1) + face.shift_x) / tex_size_x,
                (v_axis.dot(pos_1) + face.shift_y) / tex_size_y,
            );

            const pos_2 = Vec3.new(face.vertices[i + 2].x, face.vertices[i + 2].y, face.vertices[i + 2].z);
            const uv_2 = Vec2.new(
                (u_axis.dot(pos_2) + face.shift_x) / tex_size_x,
                (v_axis.dot(pos_2) + face.shift_y) / tex_size_y,
            );

            const v0: graphics.PackedVertex = .{ .x = pos_0.x, .y = pos_0.y, .z = pos_0.z, .u = uv_0.x, .v = uv_0.y };
            const v1: graphics.PackedVertex = .{ .x = pos_1.x, .y = pos_1.y, .z = pos_1.z, .u = uv_1.x, .v = uv_1.y };
            const v2: graphics.PackedVertex = .{ .x = pos_2.x, .y = pos_2.y, .z = pos_2.z, .u = uv_2.x, .v = uv_2.y };

            // TODO: Add normals to vertices!

            try builder.addTriangleFromPackedVertices(v0, v1, v2, transform);
        }
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
    if (@abs(v.x) >= @abs(v.y) and @abs(v.x) >= @abs(v.z)) return Vec3.x_axis; // 1 0 0
    if (@abs(v.y) >= @abs(v.z)) return Vec3.up; // 0 1 0
    return Vec3.z_axis; // 0 0 1
}

// simpler float parsing function that runs quicker in debug
fn parseFloat(string: []const u8) !f32 {
    var signed: bool = false;
    var decimal_point: usize = string.len - 1;
    var decimal: f32 = 0;
    for (string, 0..) |c, i| {
        switch (c) {
            '-' => signed = true,
            '0'...'9' => {
                const digit: f32 = @floatFromInt(c - '0');
                decimal = 10 * decimal + digit;
            },
            '.' => decimal_point = i,
            else => return error.UnexpectedCharacter,
        }
    }
    if (signed) decimal *= -1;
    if (decimal_point < string.len - 1) {
        const denom = std.math.pow(f32, 10, @as(f32, @floatFromInt(string.len - 1 - decimal_point)));
        decimal /= denom;
    }
    return decimal;
}

fn calculateRotatedUV(face: Face, u_axis: *Vec3, v_axis: *Vec3) void {
    const scaled_u_axis = face.u_axis.scale(1.0 / face.scale_x);
    const scaled_v_axis = face.v_axis.scale(1.0 / face.scale_y);

    // const axis = closestAxis(face.plane.normal);
    const rotation = math.Mat4.rotate(face.rotation, face.uv_direction);
    u_axis.* = scaled_u_axis.mulMat4(rotation);
    v_axis.* = scaled_v_axis.mulMat4(rotation);
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

    const allocator = gpa.allocator();

    var err: ErrorInfo = undefined;
    const map = try QuakeMap.read(allocator, test_map_file, &err);

    // Check to see if we have a world
    assert(std.mem.eql(u8, map.worldspawn.classname, "worldspawn"));
    assert(map.worldspawn.solids.items.len == 1);
    assert(map.worldspawn.solids.items[0].faces.items.len == 6);

    // Check to see that our one solid is a cube!
    for (0..6) |idx| {
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
