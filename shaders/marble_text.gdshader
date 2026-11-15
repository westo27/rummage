// Makes text look like glass marbles: each letter is clear glass in the text
// colour with a coloured ribbon swirling through it (a cat's-eye marble), a
// deeper rim, a gloss band near the top, a sparkle, and a milky glow low down
// where light coming through the glass collects.
// UiStyle.set_marble_line() sets where the line sits, in the node's own pixels.
shader_type canvas_item;

uniform float cap_top = 0.0;
uniform float baseline = 64.0;
uniform vec4 swirl_color : source_color = vec4(0.16, 0.36, 0.95, 1.0);
uniform vec4 swirl_color_2 : source_color = vec4(0.18, 0.80, 0.62, 1.0);
uniform vec4 rim_color : source_color = vec4(0.06, 0.12, 0.30, 1.0);
// How far in from the letter's edge the rim reaches, in font texture pixels.
uniform float rim_width = 2.5;
// 0..1. Small text gets less swirl and no sparkle, so it stays readable.
uniform float detail = 1.0;
// How see-through the glass is away from the rim, ribbon and gloss.
uniform float glass_clarity = 0.35;

// VERTEX is in the node's own coordinates in vertex(); the fragment step gets
// it interpolated per pixel through this varying.
varying vec2 local;
// See-through draws (the pale engraved copy behind button labels) share the
// material but should stay plain.
varying float plain;

void vertex() {
	local = VERTEX;
	plain = COLOR.a < 0.99 ? 1.0 : 0.0;
}

void fragment() {
	if (plain < 0.5) {
		float h = max(baseline - cap_top, 1.0);
		float t = (local.y - cap_top) / h;  // 0 at the top of the capitals, 1 on the baseline
		float u = local.x / h;               // across the line, in cap heights

		// The glass: the text colour, a touch deeper in the middle, milky low down.
		// (COLOR already holds the glyph texture times the text colour.)
		vec3 col = COLOR.rgb * mix(1.0, 0.82, smoothstep(0.0, 0.55, t));
		col = mix(col, vec3(0.92, 0.96, 1.0), smoothstep(0.58, 0.98, t) * 0.32);

		// Two ribbons twisting along the word: a wide one and a thin one inside
		// it. Two waves of different lengths keep it from repeating, and the
		// width swells and pinches like a ribbon turning edge-on.
		float c1 = 0.52 + 0.15 * sin(u * 2.1 + 0.7) + 0.08 * sin(u * 0.83 + 2.0);
		float w1 = 0.04 + 0.12 * abs(cos(u * 1.6 + 0.4));
		float d1 = abs(t - c1);
		float r1 = 1.0 - smoothstep(w1 * 0.6, w1, d1);
		vec3 ribbon = swirl_color.rgb * (0.75 + 0.6 * (1.0 - d1 / w1));
		col = mix(col, ribbon, r1 * 0.92 * detail);
		float c2 = c1 + 0.4 * w1 * sin(u * 3.7 + 1.3);
		float r2 = 1.0 - smoothstep(0.015, 0.04, abs(t - c2));
		col = mix(col, swirl_color_2.rgb, r2 * 0.85 * detail);
		// Clear glass: the plain body lets some of the background through,
		// while the ribbon stays solid.
		float clear_glass = glass_clarity * detail * (1.0 - r1) * (1.0 - r2);

		// The rim: how close this pixel is to the letter's edge, found by looking
		// a few texels out in eight directions for empty glyph texture.
		float inside = 1.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 off = vec2(cos(a), sin(a)) * rim_width * TEXTURE_PIXEL_SIZE;
			inside = min(inside, texture(TEXTURE, UV + off).a);
		}
		float rim = 1.0 - inside;
		col = mix(col, rim_color.rgb, rim * 0.85);

		// Gloss near the top, kept off the rim so the edge stays crisp.
		float gloss = smoothstep(0.08, 0.15, t) * (1.0 - smoothstep(0.22, 0.32, t));
		col = mix(col, vec3(1.0), gloss * 0.6 * (1.0 - rim));

		// A small four-pointed sparkle every so often along the gloss line.
		// It only shows where it lands on a letter.
		vec2 s = vec2((fract(u * 0.55 + 0.35) - 0.5) / 0.55, t - 0.2);
		float star = max(0.0, 1.0 - abs(s.x) / 0.16) * max(0.0, 1.0 - abs(s.y) / 0.025)
			+ max(0.0, 1.0 - abs(s.y) / 0.16) * max(0.0, 1.0 - abs(s.x) / 0.025);
		col = mix(col, vec3(1.0), clamp(star, 0.0, 1.0) * detail * (1.0 - rim));

		COLOR.rgb = col;
		COLOR.a *= 1.0 - clear_glass * (1.0 - rim) * (1.0 - gloss);
	}
}
