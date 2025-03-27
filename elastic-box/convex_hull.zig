const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const Particle = @import("main.zig").Particle;

fn scalarCrossProduct(a: rl.Vector2, b: rl.Vector2) f32 {
    return a.x * b.y - a.y * b.x;
}

// returns True if p is to the right of the line from a to b
fn pointIsRightOfLine(p: rl.Vector2, a: rl.Vector2, b: rl.Vector2) bool {
    const ab = rl.Vector2{ .x = b.x - a.x, .y = b.y - a.y };
    const ap = rl.Vector2{ .x = p.x - a.x, .y = p.y - a.y };
    const scalar_xp = scalarCrossProduct(ap, ab);
    return scalar_xp < 0;
}

// From the given set of points in s_k, find farthest point, say q, from segment ab
// Add point q to convex hull at the location between a and b
// Three points a, b, and q partition the remaining points of Sk into 3 subsets: S0, S1, and S2
// where S0 are points inside triangle aqb, S1 are points on the right side of the oriented
// line from a to q, and S2 are points on the right side of the oriented line from q to b
fn findHull(s_k: []*Particle, a: rl.Vector2, b: rl.Vector2, result: *std.ArrayList(*Particle), alloc: std.mem.Allocator) !void {
    if (s_k.len == 0) return;

    var max_d_idx: usize = 0;
    var max_d: f32 = 0;

    const ab = rl.Vector2{ .x = b.x - a.x, .y = b.y - a.y };
    const ab_magnitude = @sqrt(ab.x * ab.x + ab.y * ab.y);

    for (s_k, 0..) |p, i| {
        const pa = rl.Vector2{ .x = p.position.x - a.x, .y = p.position.y - a.y };
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
    
    // Handle small cases
    if (particles.len < 3) {
        // Add all particles to the hull for cases with fewer than 3 particles
        for (particles) |*p| {
            try hull_points.append(p);
        }
        return hull_points.toOwnedSlice();
    }
    
    // Find extreme points (min_x and max_x)
    var min_x: f32 = particles[0].position.x;
    var max_x: f32 = particles[0].position.x;
    
    // First pass: find the actual min/max x values
    for (particles) |p| {
        if (p.position.x < min_x) min_x = p.position.x;
        if (p.position.x > max_x) max_x = p.position.x;
    }
    
    // Second pass: collect all particles with min_x and max_x
    var min_x_points = std.ArrayList(*Particle).init(alloc);
    defer min_x_points.deinit();
    var max_x_points = std.ArrayList(*Particle).init(alloc);
    defer max_x_points.deinit();
    
    for (particles) |*p| {
        if (p.position.x == min_x) {
            try min_x_points.append(p);
        }
        if (p.position.x == max_x) {
            try max_x_points.append(p);
        }
    }
    
    // Add all extreme points to the hull
    for (min_x_points.items) |p| {
        try hull_points.append(p);
    }
    
    for (max_x_points.items) |p| {
        // Avoid duplicates if min_x == max_x
        if (min_x != max_x) {
            try hull_points.append(p);
        }
    }
    
    // If we have only points with same x, we're done (vertical line)
    if (min_x == max_x) {
        // Sort by y-coordinate to ensure proper ordering
        orderVerticalHull(hull_points.items);
        return hull_points.toOwnedSlice();
    }
    
    // Choose one point from each extreme for the dividing line
    const a = min_x_points.items[0];
    const b = max_x_points.items[0];
    
    var s_1 = std.ArrayList(*Particle).init(alloc);
    defer s_1.deinit();
    var s_2 = std.ArrayList(*Particle).init(alloc);
    defer s_2.deinit();
    
    // Partition points
    for (particles) |*p| {
        // Skip all extreme points as they're already in the hull
        if (p.position.x == min_x or p.position.x == max_x) continue;
        
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

// Helper function to order points in a vertical line
fn orderVerticalHull(points: []*Particle) void {
    // Sort by y-coordinate
    std.sort.insertion(
        *Particle, 
        points, 
        {}, 
        struct {
            fn lessThan(_: void, a: *Particle, b: *Particle) bool {
                return a.position.y < b.position.y;
            }
        }.lessThan
    );
}
/// orders hull points order around their centroid
pub fn orderHullByAngle(hull_points: []*Particle) void {
    if (hull_points.len <= 1) return;
    
    var centroid = rl.Vector2{ .x = 0, .y = 0 };
    for (hull_points) |p| {
        centroid.x += p.position.x;
        centroid.y += p.position.y;
    }
    centroid.x /= @as(f32, @floatFromInt(hull_points.len));
    centroid.y /= @as(f32, @floatFromInt(hull_points.len));
    
    const AngleContext = struct {
        centroid: rl.Vector2,
        pub fn lessThan(context: @This(), a: *Particle, b: *Particle) bool {
            const a_angle = std.math.atan2(a.position.y - context.centroid.y, a.position.x - context.centroid.x);
            const b_angle = std.math.atan2(b.position.y - context.centroid.y, b.position.x - context.centroid.x);
            return a_angle < b_angle;
        }
    };
    
    std.sort.pdq(*Particle, hull_points, AngleContext{ .centroid = centroid }, AngleContext.lessThan);
}