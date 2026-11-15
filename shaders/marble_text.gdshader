// Makes text look like glass marbles: brighter at the top and deeper at the
// bottom, with a white gloss band across the top of the capitals and a faint
// glow near the bottom, where light coming through a marble collects.
// UiStyle.set_marble_line() sets where the line sits, in the node's own pixels.
shader_type canvas_item;

uniform float cap_top = 0.0;
uniform float baseline = 64.0;
uniform float gloss_strength = 0.55;

// The node-local height of each pixel, handed from the vertex step to the
// fragment step. VERTEX is in the node's own coordinates in vertex().
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	// 0 at the top of the capitals, 1 on the baseline.
	float t = (local_y - cap_top) / max(baseline - cap_top, 1.0);
	// In a canvas fragment shader COLOR already holds the glyph texture times
	// the text colour, so it only needs recolouring.
	vec3 base = COLOR.rgb;
	// Kept below full brightness so the gloss still shows on cream text.
	vec3 col = base * mix(0.98, 0.66, smoothstep(0.1, 1.0, t));
	// The band sits low enough to cross lowercase letters too, so it reads as
	// one reflection across the word, not a cap on the tall letters.
	float gloss = smoothstep(0.24, 0.34, t) * (1.0 - smoothstep(0.40, 0.52, t));
	col = mix(col, vec3(1.0), gloss * gloss_strength);
	float glow = smoothstep(0.62, 0.80, t) * (1.0 - smoothstep(0.84, 0.98, t));
	col += glow * 0.22 * (base + vec3(0.15));
	COLOR.rgb = col;
}
