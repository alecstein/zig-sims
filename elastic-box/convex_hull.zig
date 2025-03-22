const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

const Particle = @import("main.zig").Particle;

fn scalarCrossProduct(a: c.Vector2, b: c.Vector2) f32 {
    return a.x * b.y - a.y * b.x;
}

// returns True if p is to the right of the line from a to b
fn pointIsRightOfLine(p: c.Vector2, a: c.Vector2, b: c.Vector2) bool {
    const ab = c.Vector2{ .x = b.x - a.x, .y = b.y - a.y };
    const ap = c.Vector2{ .x = p.x - a.x, .y = p.y - a.y };
    const scalar_xp = scalarCrossProduct(ap, ab);
    return scalar_xp < 0;
}

// From the given set of points in s_k, find farthest point, say q, from segment ab
// Add point q to convex hull at the location between a and b
// Three points a, b, and q partition the remaining points of Sk into 3 subsets: S0, S1, and S2
// where S0 are points inside triangle aqb, S1 are points on the right side of the oriented
// line from a to q, and S2 are points on the right side of the oriented line from q to b
// FindHull(S1, a, q)
// FindHull(S2, q, b)
fn findHull(s_k: []*Particle, a: c.Vector2, b: c.Vector2, result: *std.ArrayList(*Particle), alloc: std.mem.Allocator) !void {
    if (s_k.len == 0) return;

    var max_d_idx: usize = 0;
    var max_d: f32 = 0;

    const ab = c.Vector2{ .x = b.x - a.x, .y = b.y - a.y };
    const ab_magnitude = @sqrt(ab.x * ab.x + ab.y * ab.y);

    for (s_k, 0..) |p, i| {
        const pa = c.Vector2{ .x = p.position.x - a.x, .y = p.position.y - a.y };
        const d = @abs(scalarCrossProduct(pa, ab) / ab_magnitude);
        if (d > max_d) {
            max_d = d;
            max_d_idx = i;
        }
    }

    // q gets added to the convex hull
    const q = s_k[max_d_idx];
    try result.append(q);

    var s_1 = std.ArrayList(*Particle).init(alloc);
    defer s_1.deinit();
    var s_2 = std.ArrayList(*Particle).init(alloc);
    defer s_2.deinit();

    for (s_k, 0..) |p, i| {
        if (i == max_d_idx) continue;
        if (pointIsRightOfLine(p.position, a, q.position)) {
            try s_1.append(p);
        } else if (pointIsRightOfLine(p.position, q.position, b)) {
            try s_2.append(p);
        }
    }

    try findHull(s_1.items, a, q.position, result, alloc);
    try findHull(s_2.items, q.position, b, result, alloc);
}

pub fn quickHull(particles: []Particle, alloc: std.mem.Allocator) ![]*Particle {
    var hull_points = std.ArrayList(*Particle).init(alloc);
    errdefer hull_points.deinit();

    if (particles.len < 3) {
        return hull_points.toOwnedSlice();
    }

    var min_x_idx: usize = 0;
    var max_x_idx: usize = 0;

    for (particles, 0..) |_, i| {
        if (particles[i].position.x < particles[min_x_idx].position.x) {
            min_x_idx = i;
        }
        if (particles[i].position.x > particles[max_x_idx].position.x) {
            max_x_idx = i;
        }
    }

    const a = &particles[min_x_idx];
    const b = &particles[max_x_idx];
    
    try hull_points.append(a);
    try hull_points.append(b);

    var s_1 = std.ArrayList(*Particle).init(alloc);
    defer s_1.deinit();
    var s_2 = std.ArrayList(*Particle).init(alloc);
    defer s_2.deinit();

    for (particles) |*p| {
        if (p == a or p == b) continue;
        if (pointIsRightOfLine(p.position, a.position, b.position)) {
            try s_1.append(p);
        } else {
            try s_2.append(p);
        }
    }

    try findHull(s_1.items, a.position, b.position, &hull_points, alloc);
    try findHull(s_2.items, b.position, a.position, &hull_points, alloc);
    
    orderHullByAngle(hull_points.items);

    return hull_points.toOwnedSlice();
}

/// Orders hull points in counter-clockwise order around their centroid
/// Takes a list of points that are already known to be on the hull
/// Returns a newly allocated slice that must be freed by the caller
pub fn orderHullByAngle(hull_points: []*Particle) void {
    if (hull_points.len <= 1) return;
    
    var centroid = c.Vector2{ .x = 0, .y = 0 };
    for (hull_points) |p| {
        centroid.x += p.position.x;
        centroid.y += p.position.y;
    }
    centroid.x /= @as(f32, @floatFromInt(hull_points.len));
    centroid.y /= @as(f32, @floatFromInt(hull_points.len));
    
    const AngleContext = struct {
        centroid: c.Vector2,
        pub fn lessThan(context: @This(), a: *Particle, b: *Particle) bool {
            const a_angle = std.math.atan2(a.position.y - context.centroid.y, a.position.x - context.centroid.x);
            const b_angle = std.math.atan2(b.position.y - context.centroid.y, b.position.x - context.centroid.x);
            return a_angle < b_angle;
        }
    };
    
    std.sort.pdq(*Particle, hull_points, AngleContext{ .centroid = centroid }, AngleContext.lessThan);
}