// Makes each letter look like a 3D glass marble: smoky clear glass you can see
// the background through, bright white light along every edge (strongest at
// the upper left), pink, blue and teal swirls floating inside, and a few tiny
// bubbles.
// UiStyle.set_marble_line() sets where the line sits, in the node's own pixels.
shader_type canvas_item;

uniform float cap_top = 0.0;
uniform float baseline = 64.0;
uniform vec4 swirl_color : source_color = vec4(0.95, 0.25, 0.70, 1.0);
uniform vec4 swirl_color_2 : source_color = vec4(0.25, 0.45, 1.0, 1.0);
uniform vec4 swirl_color_3 : source_color = vec4(0.20, 0.85, 0.80, 1.0);
// How far in from the letter's edge the bright rim reaches, in font texture pixels.
uniform float rim_width = 2.5;
// 0..1. Small text gets less swirl and no bubbles, so it stays readable.
uniform float detail = 1.0;
// How see-through the middle of the glass is.
uniform float glass_clarity = 0.7;
// Slides the swirls along, in radians. Scripts add to it a frame at a time
// (menu words while pointed at, headings always). Not TIME: Godot winds TIME
// back to 0 every hour, which would make the swirls jump.
uniform float drift = 0.0;
// 1 shows the swirls. Only titles and headings turn them on; other text is
// plain glass so it reads easily.
uniform float swirls = 0.0;
// Tests only: 1 paints each letter flat with its own random numbers, so a
// test can check every letter gets one set and keeps it.
uniform float show_key = 0.0;

// VERTEX is in the node's own coordinates in vertex(); the fragment step gets
// it interpolated per pixel through these varyings.
varying vec2 local;
// Where this pixel is inside its own letter: (0, 0) top left, (1, 1) bottom
// right. Text is drawn as one quad per letter, and Godot builds each quad's
// two triangles from six vertices in a fixed corner order, so VERTEX_ID tells
// us which corner a vertex is.
varying vec2 glyph;
// See-through draws (the pale engraved copy behind button labels) share the
// material but should stay plain.
varying float plain;

// A random-looking 0..1 number for the letter whose left edge is at `left`
// (node pixels); `k` picks a different number for the same letter. Smooth in
// `left` on purpose: `left` is worked out per pixel and is off by a hair, so
// anything that rounds it (floor, or a fract(sin * big) hash) can land on a
// step and give half a letter different swirls. Letters are tens of pixels
// apart, so these slow waves still look random from one letter to the next.
float pick(float left, float k) {
	return 0.5 + 0.5 * sin(left * (0.173 + 0.031 * k) + k * 2.399 + 1.3 * sin(left * 0.047 + k));
}

// A soft ribbon that wanders across the letter: 1 on its centre line.
float ribbon(vec2 g, float left, float k, float width) {
	// Each ribbon drifts at its own pace, so they slide past each other.
	float ph = pick(left, k) * 6.283 + drift * (0.6 + 0.8 * pick(left, k + 0.5));
	float lean = mix(-0.6, 0.6, pick(left, k + 0.25));
	float cy = 0.5 + (g.x - 0.5) * lean + 0.18 * sin(g.x * 4.0 + ph)
		+ 0.03 * sin(g.y * 5.0 + ph * 2.0);
	float w = width * (0.5 + abs(cos(g.x * 3.1 + ph)));
	return 1.0 - smoothstep(w * 0.3, w, abs(g.y - cy));
}

void vertex() {
	local = VERTEX;
	vec2 corners[6] = vec2[](vec2(0.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0),
		vec2(1.0, 0.0), vec2(0.0, 0.0), vec2(1.0, 1.0));
	glyph = corners[VERTEX_ID % 6];
	plain = COLOR.a < 0.99 ? 1.0 : 0.0;
}

void fragment() {
	if (plain < 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		vec2 g = glyph;
		// Dark text (on the light buttons) becomes dark glass that stays solid;
		// light text becomes clear glass over the background.
		float dark = 1.0 - smoothstep(0.25, 0.6, dot(COLOR.rgb, vec3(0.3, 0.59, 0.11)));

		// Which letter this is: its left edge in node pixels, worked out from
		// how fast `glyph` and `local` change across one screen pixel. Each
		// letter's swirls and bubbles come from pick(glyph_left, ...).
		float gx_rate = dFdx(g.x);
		float glyph_left = abs(gx_rate) > 1e-5 ? local.x - g.x * dFdx(local.x) / gx_rate : local.x;

		// How near the letter's edge this pixel is: look out in eight
		// directions for empty texture, close in and further in.
		float near_edge = 1.0;
		float mid_edge = 1.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 dir = vec2(cos(a), sin(a));
			near_edge = min(near_edge, texture(TEXTURE, UV + dir * rim_width * px).a);
			mid_edge = min(mid_edge, texture(TEXTURE, UV + dir * rim_width * 2.8 * px).a);
		}
		float rim = 1.0 - near_edge;
		// A second, fainter line a little way in: the far side of the glass.
		float inner = (1.0 - mid_edge) * near_edge;
		// Light from the upper left.
		float lit = 1.0 - texture(TEXTURE, UV + vec2(-0.7, -0.7) * rim_width * 1.6 * px).a;

		// The body: smoky glass, dark and see-through.
		vec3 smoke = mix(vec3(0.16, 0.18, 0.24), COLOR.rgb, 0.25 + 0.5 * dark);
		vec3 col = smoke * mix(1.2, 0.8, g.y);

		// Swirls floating inside, glowing a little where they cross.
		float s1 = ribbon(g, glyph_left, 0.0, 0.10) * detail * swirls;
		float s2 = ribbon(g, glyph_left, 1.0, 0.07) * detail * swirls;
		float s3 = ribbon(g, glyph_left, 2.0, 0.04) * detail * swirls;
		col = mix(col, swirl_color.rgb, s1 * 0.85);
		col = mix(col, swirl_color_2.rgb, s2 * 0.85);
		col = mix(col, swirl_color_3.rgb * 1.2, s3 * 0.9);

		// Bubbles: a few tiny pale dots in each letter.
		float bubbles = 0.0;
		for (int i = 0; i < 4; i++) {
			float k = 3.0 + float(i);
			vec2 c = vec2(pick(glyph_left, k), pick(glyph_left, k + 0.4)) * 0.7 + 0.15;
			float rad = 0.018 + 0.02 * pick(glyph_left, k + 0.7);
			bubbles = max(bubbles, 1.0 - smoothstep(rad * 0.5, rad, length((g - c) * vec2(1.0, 1.3))));
		}
		bubbles *= detail;
		col = mix(col, vec3(0.9, 0.95, 1.0), bubbles * 0.6);

		// Bright edges: white all round, strongest facing the light, and the
		// fainter inner line.
		// Dark glass keeps a dark outer edge so it stands out on light panels,
		// and catches the light just inside it instead.
		float edge_light = rim * (0.55 + 0.45 * lit) + inner * 0.35 * (1.0 - g.y * 0.6);
		vec3 edge_col = mix(vec3(1.0), vec3(0.05, 0.06, 0.1), dark * (1.0 - lit * 0.3));
		col = mix(col, edge_col, clamp(rim * (0.55 + 0.45 * lit), 0.0, 1.0));
		col = mix(col, vec3(1.0), clamp(inner * (0.35 + 0.5 * dark) * (1.0 - g.y * 0.6), 0.0, 1.0));
		// A soft sheen across the upper part of each letter.
		col += vec3(0.25) * smoothstep(0.45, 0.1, g.y) * smoothstep(0.0, 0.25, g.y) * (1.0 - rim);

		COLOR.rgb = col;
		float solid = clamp(max(max(edge_light, s1), max(max(s2, s3), bubbles)) + dark, 0.0, 1.0);
		COLOR.a *= 1.0 - glass_clarity * detail * (1.0 - solid);
		if (show_key > 0.5) {
			// The three numbers the first ribbon is built from, to 8 bits.
			COLOR = vec4(pick(glyph_left, 0.0), pick(glyph_left, 0.5), pick(glyph_left, 0.25),
				step(0.5, texture(TEXTURE, UV).a));
		}
	}
}
