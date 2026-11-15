shader_type spatial;
// Fakes rounded edges on blocky models after the scene is drawn. Drawn on a
// quad that covers the whole screen (see edge_round.gd), it reads each pixel's
// surface direction (the normal) and depth that Godot already rendered, and
// looks a few centimetres either side. Where the surface turns outward (a
// convex edge) it brightens, as a rounded edge catching light would; where it
// turns inward (a crease) it darkens a little. Flat joins between two blocks
// don't turn, so they leave no seam.
//
// Needs the Forward+ renderer (for the normal texture). Doesn't see
// see-through things (beam, glows), which is what we want.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

// How wide the fake bevel is, in metres.
uniform float radius = 0.03;
// Strength of the edge light and the crease shadow.
uniform float highlight = 1.2;
uniform float crease = 0.35;
// Neighbours further than this (metres, in depth) belong to something else,
// such as the wall behind an object's outline, and are ignored.
uniform float depth_cutoff = 0.06;
// Caps how wide the bevel gets up close, in pixels.
uniform float max_pixels = 10.0;

void vertex() {
	// Skip the camera: put the quad straight onto the screen.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
}

// The neighbour's normal, or ours if it's on something else.
vec3 neighbour(vec2 uv, float z, vec3 n, mat4 inv_proj) {
	float nz = linear_depth(uv, inv_proj);
	return abs(nz - z) > depth_cutoff * (1.0 + z * 0.15) ? n : view_normal(uv);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	float z = linear_depth(uv, INV_PROJECTION_MATRIX);
	vec3 n = view_normal(uv);
	// The bevel's width on screen: `radius` metres at this depth.
	float px = clamp(radius * PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y * 0.5 / z, 1.0, max_pixels);
	// Looks out at three distances and averages, so the effect fades
	// smoothly away from the edge like a real bevel instead of a hard line.
	float curve = 0.0;
	for (int i = 1; i <= 3; i++) {
		vec2 s = px * float(i) / 3.0 / VIEWPORT_SIZE;
		vec3 r = neighbour(uv + vec2(s.x, 0.0), z, n, INV_PROJECTION_MATRIX);
		vec3 l = neighbour(uv - vec2(s.x, 0.0), z, n, INV_PROJECTION_MATRIX);
		vec3 u = neighbour(uv - vec2(0.0, s.y), z, n, INV_PROJECTION_MATRIX);
		vec3 d = neighbour(uv + vec2(0.0, s.y), z, n, INV_PROJECTION_MATRIX);
		// How much the normal spreads out here: positive on a convex edge,
		// negative in a crease. (Screen v runs down, view y runs up.)
		curve += (r.x - l.x) + (u.y - d.y);
	}
	curve /= 3.0;
	// Gentle curves (balls, the teddy) are already round: leave them be.
	float convex = smoothstep(0.08, 0.6, curve);
	float concave = smoothstep(0.08, 0.6, -curve);
	// Sky and far background have no surface to round.
	float on = z < 50.0 ? 1.0 : 0.0;
	// The edge light is added (a little even on black), so dark wood still
	// catches it; the crease darkens.
	col += on * convex * highlight * (col + vec3(0.03));
	col *= 1.0 - on * concave * crease;
	ALBEDO = col;
}
