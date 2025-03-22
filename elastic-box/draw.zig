const c = @cImport({
    @cInclude("raylib.h");
});
const Particle = @import("main.zig").Particle;

pub fn drawConvexHull(convex_hull: []const *Particle, color: c.Color, line_size: f32) void {
    if (convex_hull.len < 3) return;

    var i: usize = 0;
    while (i < convex_hull.len) : (i += 1) {
        const nextIndex = (i + 1) % convex_hull.len;
        c.DrawLineEx(convex_hull[i].position, convex_hull[nextIndex].position, line_size, color);
    }
}

pub fn draw(particles: []const Particle, convex_hull: []const *Particle, texture: c.RenderTexture2D) void {
    c.BeginTextureMode(texture);
    c.ClearBackground(c.BLACK);
    for (particles) |particle| {
        c.DrawPixelV(particle.position, c.WHITE);
        // c.DrawCircleV(particle.position, 2.0, c.WHITE);
    }
    drawConvexHull(convex_hull, c.RED, 4);
    c.EndTextureMode();
    c.DrawTexture(texture.texture, 0, 0, c.WHITE);
}