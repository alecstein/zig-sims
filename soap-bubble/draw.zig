const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const main = @import("main.zig");
const Particle = main.Particle;

const screen_width = main.screen_width;
const screen_height = main.screen_height;

pub fn drawSystem(
    alloc: std.mem.Allocator, 
    particles: []const Particle,
    convex_hull: []const *Particle,
    texture: rl.RenderTexture2D,
) !void {

    const line_size: f32 = 5;
    const line_color: rl.Color = rl.GREEN;
    const particle_color: rl.Color = rl.WHITE;

    const width: usize = @intCast(screen_width);
    const height: usize = @intCast(screen_height);
    var pixel_buffer = try alloc.alloc(rl.Color, width * height);
    defer alloc.free(pixel_buffer);

    for (pixel_buffer) |*p| {
        p.* = rl.BLACK;
    }

    for (particles) |particle| {
        const px = particle.position.x;
        const py = particle.position.y;
        const ix: usize = @intFromFloat(px);
        const iy: usize = @intFromFloat(py);
        const index = iy * width + ix;
        pixel_buffer[index] = particle_color;
    }

    rl.UpdateTexture(texture.texture, pixel_buffer.ptr);
    rl.DrawTexture(texture.texture, 0, 0, rl.WHITE);

    // draw convex hull
    for (convex_hull, 0..) |particle, i| {
        const nextIndex = (i + 1) % convex_hull.len;
        rl.DrawLineEx(particle.position, convex_hull[nextIndex].position, line_size, line_color);
    }
}