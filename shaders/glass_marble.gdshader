// A caught creature in the marble bag as a glass marble, matching the menu
// text (marble_text.gdshader): smoky see-through glass, bright white light
// round the edge (strongest at the upper left), a swirl in the creature's
// colour and a few tiny bubbles.
// BagMarble draws one quad over the ball with UVs 0..1; this shades it as a
// sphere. The quad is kept screen-upright, so the light stays at the top left,
// and `spin` turns the swirl and bubbles so they roll with the ball.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.95, 0.25, 0.70, 1.0);
uniform float spin = 0.0;
// 0..1, different for each ball, so no two swirls are the same.
uniform float seed = 0.0;
// How see-through the middle of the glass is.
uniform float glass_clarity = 0.4;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// A soft ribbon across the ball: 1 on its wavy centre line.
float ribbon(vec2 q, float s, float width) {
	float ph = s * 6.283;
	float lean = mix(-0.8, 0.8, hash(s + 0.3));
	float cy = q.x * lean + 0.25 * sin(q.x * 2.5 + ph) + mix(-0.2, 0.2, hash(s + 0.6));
	float w = width * (0.6 + 0.6 * abs(cos(q.x * 2.0 + ph)));
	return 1.0 - smoothstep(w * 0.3, w, abs(q.y - cy));
}

void fragment() {
	// p: -1..1 across the ball, y down. d: distance from the centre.
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float aa = fwidth(d) * 1.5;
	float inside = 1.0 - smoothstep(1.0 - aa, 1.0, d);
	// The sphere's surface: z is 1 facing us, 0 at the edge.
	float z = sqrt(max(1.0 - d * d, 0.0));
	// The swirl's own coordinates, turned with the ball.
	vec2 q = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * p;
	// Seen through a sphere, the inside bulges: things near the edge squeeze.
	q *= mix(0.75, 1.0, z);

	// The body: smoky glass with a little of the creature's colour in it,
	// lighter at the top.
	vec3 smoke = mix(vec3(0.16, 0.18, 0.24), tint.rgb, 0.55);
	vec3 col = smoke * mix(1.25, 0.75, UV.y);

	// The swirl: a broad band in the creature's colour (so you can still
	// tell who's who), a pale thin one and a lighter accent.
	float s1 = ribbon(q, seed, 0.45);
	float s2 = ribbon(q, seed + 0.37, 0.09);
	float s3 = ribbon(q, seed + 0.71, 0.06);
	// Deeper inside the ball, the swirl glows a little.
	col = mix(col, tint.rgb * (0.95 + 0.4 * z), s1);
	col = mix(col, vec3(0.95, 0.97, 1.0), s2 * 0.6);
	col = mix(col, tint.rgb * 1.3 + 0.15, s3 * 0.7);

	// Bubbles: a few tiny pale dots that roll with the swirl.
	float bubbles = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 c = (vec2(hash(seed + float(i) * 1.1), hash(seed + float(i) * 2.3 + 5.0)) - 0.5) * 1.1;
		float rad = 0.035 + 0.035 * hash(seed + float(i) * 3.7);
		bubbles = max(bubbles, 1.0 - smoothstep(rad * 0.5, rad, length(q - c)));
	}
	col = mix(col, vec3(0.9, 0.95, 1.0), bubbles * 0.7);

	// Edge light: white all round, strongest facing the light at the upper
	// left, and a fainter line a little way in (the far side of the glass).
	float lit = clamp(dot(p / max(d, 1e-4), vec2(-0.707, -0.707)) * 0.5 + 0.5, 0.0, 1.0);
	float rim = smoothstep(0.80, 0.96, d);
	float inner = smoothstep(0.66, 0.74, d) * (1.0 - smoothstep(0.76, 0.84, d));
	col = mix(col, vec3(1.0), clamp(rim * (0.45 + 0.55 * lit), 0.0, 1.0));
	col = mix(col, vec3(1.0), inner * 0.3 * lit);
	// A dark line right at the edge, so balls stand apart in the pile.
	col = mix(col, vec3(0.05, 0.06, 0.1), smoothstep(0.95, 1.0, d) * (1.0 - lit) * 0.8);
	// A soft sheen over the upper part, and a sharp highlight at the top left.
	col += vec3(0.15) * smoothstep(0.1, -0.6, p.y) * (1.0 - rim);
	float glint = 1.0 - smoothstep(0.10, 0.16, length(p - vec2(-0.5, -0.6)));
	col = mix(col, vec3(1.0), glint * 0.9);

	float solid = clamp(max(max(rim, s1), max(max(s2, s3), max(bubbles, glint))), 0.0, 1.0);
	COLOR = vec4(col, inside * (1.0 - glass_clarity * (1.0 - solid)));
}
