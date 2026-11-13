// The night sky outside the window: deep navy overhead fading to a dusky
// purple near the horizon, twinkling stars, a glowing moon, and a few faint
// clouds drifting slowly past, lit from behind by the moon.
//
// Drawn on a big flat panel a couple of metres outside the wall; through the
// window it reads as distant sky. Unshaded: it's a light source, not lit by
// the room. The moon is brighter than white, so the bloom gives it a halo.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 zenith : source_color = vec3(0.03, 0.05, 0.16);
uniform vec3 horizon : source_color = vec3(0.2, 0.14, 0.32);
// Where the moon sits on the panel (0..1 across and down), and its size.
uniform vec2 moon_at = vec2(0.62, 0.3);
uniform float moon_radius = 0.035;
uniform vec3 moon_colour : source_color = vec3(1.0, 0.96, 0.85);
// How fast the clouds drift, in panel-widths per second.
uniform float drift = 0.003;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth random hills: a random number at each grid corner, blended.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Several layers of noise at finer and finer scales: billowy cloud shapes.
float cloud_shape(vec2 p) {
	float total = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 5; i++) {
		total += noise(p) * weight;
		p *= 2.03;
		weight *= 0.5;
	}
	return total;
}

void fragment() {
	// UV.y is 0 at the top of the panel and 1 at the bottom. The panel is
	// twice as wide as it is tall, so x is stretched to keep things round.
	vec2 uv = vec2(UV.x * 2.0, UV.y);
	vec3 sky = mix(zenith, horizon, smoothstep(0.1, 1.0, UV.y));

	// Stars: one possible star per small grid cell, most cells empty, each
	// twinkling at its own speed. Fewer near the hazy horizon.
	vec2 grid = uv * 90.0;
	vec2 cell = floor(grid);
	float chance = hash(cell);
	if (chance > 0.93) {
		vec2 spot = vec2(hash(cell + 7.1), hash(cell + 3.7));
		float d = length(fract(grid) - spot);
		float twinkle = 0.6 + 0.4 * sin(TIME * (1.5 + chance * 4.0) + chance * 40.0);
		float star = smoothstep(0.12, 0.0, d) * twinkle * (1.0 - smoothstep(0.5, 0.95, UV.y));
		sky += vec3(0.9, 0.92, 1.0) * star * 1.2;
	}

	// The moon: a bright disc with a soft glow around it.
	vec2 moon = vec2(moon_at.x * 2.0, moon_at.y);
	float md = length(uv - moon);
	float disc = smoothstep(moon_radius, moon_radius - 0.004, md);
	float halo = exp(-md * 9.0) * 0.35;
	sky += moon_colour * (disc * 1.6 + halo);

	// Clouds: dark shapes drifting across, their edges lit silver near the moon.
	vec2 p = vec2(uv.x * 2.0 + TIME * drift * 4.0, uv.y * 2.2);
	float c = cloud_shape(p * 1.6);
	float amount = smoothstep(0.55, 0.78, c) * (1.0 - smoothstep(0.6, 0.95, UV.y));
	vec3 cloud = mix(vec3(0.07, 0.07, 0.15), vec3(0.45, 0.45, 0.6), exp(-md * 3.0));
	ALBEDO = mix(sky, cloud, amount * 0.85);
}
