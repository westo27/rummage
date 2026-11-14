// Shared by the surface shaders for the pixel filter's look. A global
// uniform is one value every shader can read, set from code with
// RenderingServer.global_shader_parameter_set (Settings.apply_pixel_filter).
// It's declared in Project Settings > Shader Globals.
//
// pixel_texels: texels per metre (or per canvas, for the pictures) while the
// pixel filter is on; 0 when it's off, which leaves the surfaces smooth.
global uniform float pixel_texels;

bool pixel_art() {
	return pixel_texels > 0.0;
}

// Moves a position to the middle of its texel, so a whole texel shows one
// flat colour. `scale` multiplies the grid (2.0 = twice as fine).
vec2 pixel_snap(vec2 p, float scale) {
	if (!pixel_art()) {
		return p;
	}
	float n = pixel_texels * scale;
	return (floor(p * n) + 0.5) / n;
}

// How soft an edge drawn from distance `d` should be: a hard step for pixel
// art, otherwise about one screen pixel (fwidth is how much `d` changes from
// one pixel to the next).
float pixel_edge(float d) {
	return pixel_art() ? 1e-5 : fwidth(d) + 0.0005;
}
