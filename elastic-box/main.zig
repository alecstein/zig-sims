const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const quickHull = @import("convex_hull.zig").quickHull;
const draw = @import("draw.zig").draw;

var texture: c.RenderTexture2D = undefined;

const screen_width: i32 = 800;
const screen_height: i32 = 450;

pub const Particle = struct {
    position: c.Vector2,
    velocity: c.Vector2,

    pub fn init(px: f32, py: f32, vx: f32, vy: f32) Particle {
        return Particle{
            .position = .{ .x = px, .y = py },
            .velocity = .{ .x = vx, .y = vy },
        };
    }
};

fn initializeParticles(particles: []Particle, max_init_position: f32, max_init_velocity: f32) void {
    var seed: u64 = undefined;
    std.posix.getrandom(std.mem.asBytes(&seed)) catch |err| {
        std.debug.print("failed to get random seed: {}\n", .{err});
        return;
    };
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();
    for (particles) |*p| {
        p.* = Particle.init(
            screen_width/2 + max_init_position * 2 * (rand.float(f32) - 0.5),
            screen_height/2 + max_init_position * 2 * (rand.float(f32) - 0.5), 
            max_init_velocity * 2 * (rand.float(f32) - 0.5),
            max_init_velocity * 2 * (rand.float(f32) - 0.5),
        );
    }
}

fn update(particles: []Particle, convex_hull: []const *Particle, k: f32) void {
    for (particles) |*particle| {
        particle.position.x += particle.velocity.x;
        particle.position.y += particle.velocity.y;
        if ((particle.position.x >= screen_width) or (particle.position.x <= 0)) {
            particle.velocity.x = -particle.velocity.x;
        }
        if ((particle.position.y >= screen_height) or (particle.position.y <= 0)) {
            particle.velocity.y = -particle.velocity.y;
        }
    }
    applyForces(convex_hull, k);
}

// L(p) = |p-a| + |p-b| (sum of distances from p to neighboring points)
// The gradient is:
// ∇L(p) = (p-a)/|p-a| + (p-b)/|p-b|
// in other words, it's the sum of unit vectors
fn applyForces(convex_hull: []const *Particle, k: f32) void {
    if (convex_hull.len < 3) return;

    for (convex_hull, 0..) |_, i| {
        const nxt_idx = (i + 1) % convex_hull.len;
        const prv_idx = if (i == 0) convex_hull.len - 1 else i - 1;

        const a = convex_hull[prv_idx].position;
        const b = convex_hull[nxt_idx].position;
        const p = convex_hull[i].position;

        const pa = c.Vector2{
            .x = a.x - p.x,
            .y = a.y - p.y,
        };
        
        const pb = c.Vector2{
            .x = b.x - p.x,
            .y = b.y - p.y,
        };

        const pa_normed = c.Vector2{
            .x = pa.x / @sqrt(pa.x * pa.x + pa.y * pa.y),
            .y = pa.y / @sqrt(pa.x * pa.x + pa.y * pa.y),
        };
        
        const pb_normed = c.Vector2{
            .x = pb.x / @sqrt(pb.x * pb.x + pb.y * pb.y),
            .y = pb.y / @sqrt(pb.x * pb.x + pb.y * pb.y),
        };

        const force = c.Vector2{
            .x = pa_normed.x + pb_normed.x,
            .y = pa_normed.y + pb_normed.y,
        };

        convex_hull[i].velocity.x += force.x * k;
        convex_hull[i].velocity.y += force.y * k;
    }
}

pub fn main() !void {
    const n_particles: usize = 50000;
    const max_init_position: f32 = 5;
    const max_init_velocity: f32 = 0.1;
    const surf_tension: f32 = 0.3;
    const font_size: usize = 19;

    const n_particles_text = std.fmt.allocPrintZ(allocator, "particles: {d}", .{n_particles}) catch "format failed";
    const max_init_velocity_text = std.fmt.allocPrintZ(allocator, "max_init_vel: {d:.2}", .{max_init_velocity}) catch "format failed";
    const surf_tension_text = std.fmt.allocPrintZ(allocator, "surf_tension: {d:.2}", .{surf_tension}) catch "format failed";
    defer allocator.free(n_particles_text);
    defer allocator.free(max_init_velocity_text);
    defer allocator.free(surf_tension_text);

    c.InitWindow(screen_width, screen_height, "zig-sim");
    texture = c.LoadRenderTexture(screen_width, screen_height);
    c.SetTargetFPS(120);

    var particles: [n_particles]Particle = undefined;

    initializeParticles(&particles, max_init_position, max_init_velocity);

    while (!c.WindowShouldClose()) {

        if (c.IsKeyPressed(c.KEY_ESCAPE)) {
            break;
        }

        if (c.IsKeyPressed(c.KEY_SPACE)) {
            initializeParticles(&particles, max_init_position, max_init_velocity);
        }
        
        c.BeginDrawing();
        const convex_hull = try quickHull(&particles, allocator);
        defer allocator.free(convex_hull);
        update(&particles, convex_hull, surf_tension);
        draw(&particles, convex_hull, texture);

        c.DrawText(n_particles_text, 10, 10, font_size, c.WHITE); // Draw the title at position (10,10) with font size 20
        c.DrawText(max_init_velocity_text.ptr, 10, 10 + (4 + font_size), font_size, c.WHITE);
        c.DrawText(surf_tension_text.ptr, 10, 10 + 2*(4 + font_size), font_size, c.WHITE);
        c.EndDrawing();
    }

    c.UnloadRenderTexture(texture);
    c.CloseWindow();
}
