// Makes each letter look like a cat's-eye glass marble: clear glass in the
// text colour that's thicker and darker toward its edges, a coloured ribbon
// twisting down through the middle of the letter, light caught along the
// upper-left edges, a curved highlight, a milky glow low down where light
// collects, and now and then a sparkle.
// UiStyle.set_marble_line() sets where the line sits, in the node's own pixels.
shader_type canvas_item;

uniform float cap_top = 0.0;
uniform float baseline = 64.0;
uniform vec4 swirl_color : source_color = vec4(0.16, 0.36, 0.95, 1.0);
uniform vec4 swirl_color_2 : source_color = vec4(0.18, 0.80, 0.62, 1.0);
uniform vec4 rim_color : source_color = vec4(0.06, 0.12, 0.30, 1.0);
// How far in from the letter's edge the glass thickens, in font texture pixels.
uniform float rim_width = 2.5;
// 0..1. Small text gets less swirl and no sparkle, so it stays readable.
uniform float detail = 1.0;
// How see-through the middle of the glass is.
uniform float glass_clarity = 0.3;

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

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// 1 where the font texture is empty a little way off in direction `dir`.
float edge_toward(sampler2D tex, vec2 uv, vec2 dir, vec2 px) {
	return 1.0 - texture(tex, uv + dir * px).a;
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

		// Which letter this is, as a random number: the letter's left edge in
		// node pixels, worked out from how fast `glyph` and `local` change
		// across one screen pixel.
		float gx_rate = dFdx(g.x);
		float glyph_left = abs(gx_rate) > 1e-5 ? local.x - g.x * dFdx(local.x) / gx_rate : local.x;
		float r = hash(floor(glyph_left * 0.25));

		// The glass is thicker toward the letter's edge (found by looking out
		// in eight directions for empty texture), so the edge is darker and
		// solid and the middle is clearer.
		float inside = 1.0;
		float deep = 1.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			inside = min(inside, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * rim_width * px).a);
			deep = min(deep, texture(TEXTURE, UV + vec2(cos(a + 0.39), sin(a + 0.39)) * rim_width * 2.6 * px).a);
		}
		float rim = 1.0 - inside;
		float thick = 1.0 - deep;  // a wider band in from the edge

		// (COLOR already holds the glyph texture times the text colour.)
		vec3 col = COLOR.rgb;
		col = mix(col, rim_color.rgb, thick * 0.18);
		// Milky glow low in the letter, where light through a marble collects.
		col = mix(col, vec3(0.93, 0.97, 1.0), smoothstep(0.55, 0.92, g.y) * 0.35 * (1.0 - rim));

		// The ribbon runs top to bottom through the letter, leaning and
		// wiggling, and swells and pinches like a ribbon turning edge-on.
		// Each letter gets its own twist from `r`.
		float phase = r * 6.283;
		float lean = mix(-0.25, 0.25, hash(r + 1.7));
		float cx = 0.5 + (g.y - 0.5) * lean + 0.13 * sin(g.y * 3.8 + phase);
		float w = 0.11 + 0.12 * abs(cos(g.y * 2.9 + phase));
		float d = abs(g.x - cx);
		float ribbon = (1.0 - smoothstep(w * 0.55, w, d)) * detail;
		// Darker at the ribbon's own edges, so it looks rounded and inside the glass.
		vec3 ribbon_col = swirl_color.rgb * (0.55 + 0.75 * (1.0 - d / w));
		col = mix(col, ribbon_col, ribbon * 0.95);
		float cx2 = cx + 0.45 * w * sin(g.y * 6.0 + phase * 1.3);
		float thread = (1.0 - smoothstep(0.018, 0.045, abs(g.x - cx2))) * detail;
		col = mix(col, swirl_color_2.rgb, thread * 0.9);

		// Light from the upper left: a bright line just inside the upper-left
		// edges and a shadow just inside the lower-right ones.
		float lit = edge_toward(TEXTURE, UV, vec2(-0.7, -0.7), px * rim_width * 1.2);
		float shade = edge_toward(TEXTURE, UV, vec2(0.7, 0.7), px * rim_width * 1.2);
		col = mix(col, rim_color.rgb * 0.6, shade * 0.6);
		col = mix(col, vec3(1.0), lit * 0.75);

		// A curved highlight around the upper left of the letter, like a
		// window reflected in a marble.
		vec2 p = (g - 0.5) * vec2(1.0, 1.15);
		float arc = smoothstep(0.26, 0.31, length(p)) * (1.0 - smoothstep(0.33, 0.40, length(p)));
		arc *= smoothstep(0.35, 0.85, dot(normalize(p + 1e-4), vec2(-0.6, -0.8)));
		arc *= detail * (1.0 - rim);
		col = mix(col, vec3(1.0), arc * 0.7);

		// A sparkle on about a third of the letters.
		vec2 s = (g - vec2(0.34, 0.3)) * vec2(1.0, 1.2);
		float star = max(0.0, 1.0 - abs(s.x) / 0.14) * max(0.0, 1.0 - abs(s.y) / 0.02)
			+ max(0.0, 1.0 - abs(s.y) / 0.14) * max(0.0, 1.0 - abs(s.x) / 0.02);
		star = clamp(star * step(0.66, hash(r + 4.1)) * detail, 0.0, 1.0);
		col = mix(col, vec3(1.0), star);

		COLOR.rgb = col;
		// Clear glass lets the background through in the middle; the thick
		// edge, the ribbon and the highlights stay solid.
		float solid = clamp(max(max(thick, ribbon), max(max(lit, arc), max(thread, star))), 0.0, 1.0);
		COLOR.a *= 1.0 - glass_clarity * detail * (1.0 - solid);
	}
}
