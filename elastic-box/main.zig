const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

var dba = std.heap.DebugAllocator(.{}){};
const allocator = dba.allocator();

const quickHull = @import("convex_hull.zig").quickHull;
const drawSystem = @import("draw.zig").drawSystem;

pub const screen_width: i32 = 800;
pub const screen_height: i32 = 450;

pub const Particle = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,

    pub fn init(px: f32, py: f32, vx: f32, vy: f32) Particle {
        return Particle{
            .position = .{ .x = px, .y = py },
            .velocity = .{ .x = vx, .y = vy },
        };
    }
};

fn initializeParticles(particles: []Particle, max_init_position: f32, max_init_velocity: f32) !void {
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
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

// this still needs to have the order checked
fn update(particles: []Particle, convex_hull: []const *Particle, surf_tension: f32) void {

    applyForces(convex_hull, surf_tension);

    // we need to handle boundaries carefully. for us, it's
    // better if particles never leave the window at all.
    // to that end, we test if the particles will leave the boundary on the next step.
    // if they will, we flip the velocity instead
    for (particles) |*particle| {
        const trial_position_x = particle.position.x + particle.velocity.x;
        if ((trial_position_x >= screen_width) or (trial_position_x <= 0)) {
            particle.velocity.x = -particle.velocity.x;
        } else {
            particle.position.x = trial_position_x;
        }
        const trial_position_y = particle.position.y + particle.velocity.y;
        if ((trial_position_y >= screen_height) or (trial_position_y <= 0)) {
            particle.velocity.y = -particle.velocity.y;
        } else {
            particle.position.y = trial_position_y;
        }
        // particle.position.x += particle.velocity.x;
        // particle.position.y += particle.velocity.y;
    }
}

// model: force on p is proportional to ∇L(p.position)
// L(p) = |p-a| + |p-b| 
// ∇L(p) = (p-a)/|p-a| + (p-b)/|p-b|
// just need to sum these unit vectors
fn applyForces(convex_hull: []const *Particle, surf_tension: f32) void {
    if (convex_hull.len < 3) return;

    for (convex_hull, 0..) |_, i| {
        const nxt_idx = (i + 1) % convex_hull.len;
        const prv_idx = if (i == 0) convex_hull.len - 1 else i - 1;

        const a = convex_hull[prv_idx].position;
        const b = convex_hull[nxt_idx].position;
        const p = convex_hull[i].position;

        const pa = rl.Vector2{
            .x = a.x - p.x,
            .y = a.y - p.y,
        };
        
        const pb = rl.Vector2{
            .x = b.x - p.x,
            .y = b.y - p.y,
        };

        const pa_normed = rl.Vector2{
            .x = pa.x / @sqrt(pa.x * pa.x + pa.y * pa.y),
            .y = pa.y / @sqrt(pa.x * pa.x + pa.y * pa.y),
        };
        
        const pb_normed = rl.Vector2{
            .x = pb.x / @sqrt(pb.x * pb.x + pb.y * pb.y),
            .y = pb.y / @sqrt(pb.x * pb.x + pb.y * pb.y),
        };

        const force = rl.Vector2{
            .x = pa_normed.x + pb_normed.x,
            .y = pa_normed.y + pb_normed.y,
        };

        convex_hull[i].velocity.x += force.x * surf_tension;
        convex_hull[i].velocity.y += force.y * surf_tension;
    }
}

// Add this function to calculate total energy
fn calculateTotalEnergy(particles: []Particle, convex_hull: []const *Particle, surf_tension: f32) f32 {
    // Calculate kinetic energy of ALL particles
    var kinetic_energy: f32 = 0.0;
    for (particles) |particle| {
        kinetic_energy += 0.5 * (particle.velocity.x * particle.velocity.x + 
                                 particle.velocity.y * particle.velocity.y);
    }
    
    // Calculate perimeter length (potential energy)
    var perimeter: f32 = 0.0;
    if (convex_hull.len > 1) {
        for (convex_hull, 0..) |_, i| {
            const nxt_idx = (i + 1) % convex_hull.len;
            const p1 = convex_hull[i].position;
            const p2 = convex_hull[nxt_idx].position;
            
            const dx = p2.x - p1.x;
            const dy = p2.y - p1.y;
            perimeter += @sqrt(dx * dx + dy * dy);
        }
    }
    
    const potential_energy = surf_tension * perimeter;
    
    return kinetic_energy + potential_energy;
}



pub fn main() !void {
    const n_particles: usize = 10000;
    const max_init_position: f32 = 20;
    const max_init_velocity: f32 = 0.2;
    const surf_tension: f32 = 0.1;
    const font_size: usize = 19;
    const text_color: rl.Color = rl.WHITE;

    const n_particles_text = std.fmt.allocPrintZ(allocator, "particles: {d}", .{n_particles}) catch "format failed";
    const max_init_velocity_text = std.fmt.allocPrintZ(allocator, "max_init_vel: {d:.2}", .{max_init_velocity}) catch "format failed";
    const surf_tension_text = std.fmt.allocPrintZ(allocator, "surf_tension: {d:.2}", .{surf_tension}) catch "format failed";
    defer allocator.free(n_particles_text);
    defer allocator.free(max_init_velocity_text);
    defer allocator.free(surf_tension_text);

    rl.InitWindow(screen_width, screen_height, "zig-soap-bubble");
    rl.SetTargetFPS(60);

    const texture = rl.LoadRenderTexture(screen_width, screen_height);
    defer rl.UnloadRenderTexture(texture);


    var particles: [n_particles]Particle = undefined;

    try initializeParticles(&particles, max_init_position, max_init_velocity);

    while (!rl.WindowShouldClose()) {

        if (rl.IsKeyPressed(rl.KEY_ESCAPE)) {
            break;
        }

        if (rl.IsKeyPressed(rl.KEY_SPACE)) {
            try initializeParticles(&particles, max_init_position, max_init_velocity);
        }
        
        rl.BeginDrawing();
        const convex_hull = try quickHull(&particles, allocator);
        defer allocator.free(convex_hull);
        try drawSystem(allocator, &particles, convex_hull, texture);
        // drawSystem(&particles, convex_hull, texture);
        update(&particles, convex_hull, surf_tension);
        const total_energy = calculateTotalEnergy(&particles, convex_hull, surf_tension);
        const total_energy_text = std.fmt.allocPrintZ(allocator, "total_energy: {d:.2}", .{total_energy}) catch "format failed";
        defer allocator.free(total_energy_text);
        
        rl.DrawText(n_particles_text, 10, 10, font_size, text_color); 
        rl.DrawText(max_init_velocity_text.ptr, 10, 10 + (4 + font_size), font_size, text_color);
        rl.DrawText(surf_tension_text.ptr, 10, 10 + 2*(4 + font_size), font_size, text_color);
        rl.DrawText(total_energy_text.ptr, 10, 10 + 3*(4 + font_size), font_size, text_color);
        rl.EndDrawing();
    }

    rl.UnloadRenderTexture(texture);
    rl.CloseWindow();
}
