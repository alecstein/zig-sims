const c = @cImport({
    @cInclude("raylib.h");
});
const Particle = @import("main.zig").Particle;

pub fn drawSystem(particles: []const Particle, convex_hull: []const *Particle, texture: c.RenderTexture2D) void {
    const line_size: f32 = 5;
    const line_color: c.Color = c.GREEN;
    const particle_color: c.Color = c.WHITE;
    c.BeginTextureMode(texture);
    c.ClearBackground(c.BLACK);

    // draw particles
    for (particles) |particle| {
        // can draw as pixels or circles
        // pixels are much more efficient
        c.DrawPixelV(particle.position, particle_color);
        // c.DrawCircleV(particle.position, 2.0, particle_color);
    }
    // draw convex hull
    for (convex_hull, 0..) |particle, i| {
        const nextIndex = (i + 1) % convex_hull.len;
        c.DrawLineEx(particle.position, convex_hull[nextIndex].position, line_size, line_color);
    }

    c.EndTextureMode();
    c.DrawTexture(texture.texture, 0, 0, c.WHITE);
}