// The rug in the main room: a rounded rectangle with a raspberry border, an
// orange stripe inside it and a cream middle, with a faint woven texture.
// It's drawn on a flat plane (the cloth in scenes/props/rug.tscn); anything outside the rounded shape is cut away.
shader_type spatial;
// Drawn on both sides, so it still shows when lifted and tipped over.
render_mode cull_disabled;
#include "res://shaders/pixel_art.gdshaderinc"

uniform vec3 field : source_color = vec3(0.98, 0.88, 0.70);
uniform vec3 border : source_color = vec3(0.84, 0.22, 0.40);
uniform vec3 stripe : source_color = vec3(0.98, 0.58, 0.16);
// Must match the plane's size in metres.
uniform vec2 size = vec2(4.6, 3.2);
uniform float corner = 0.4;

void vertex() {
	// Drawn a few millimetres above where the cloth lies, so it covers the
	// trapdoor drawn on the floor beneath it.
	VERTEX.y += 0.008;
}

void fragment() {
	vec2 p = pixel_snap((UV - 0.5) * size, 1.0);  // metres from the rug's centre
	// Signed distance to a rounded rectangle: below zero is inside.
	vec2 q = abs(p) - (size * 0.5 - corner);
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
	if (dist > 0.0) {
		discard;
	}
	float inset = -dist;  // metres in from the edge
	vec3 colour = field;
	if (inset < 0.24) {
		colour = border;
	} else if (inset > 0.33 && inset < 0.42) {
		colour = stripe;
	}
	float weave = 0.94 + 0.06 * sin(p.x * 140.0) * sin(p.y * 140.0);
	if (pixel_art()) {
		// A checker of two shades reads as weave at this size.
		vec2 t = floor(p * pixel_texels);
		weave = mod(t.x + t.y, 2.0) < 1.0 ? 0.97 : 0.92;
	}
	ALBEDO = colour * weave;
	ROUGHNESS = 1.0;
}
