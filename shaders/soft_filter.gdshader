shader_type canvas_item;
// The soft low-resolution look: the 3D view as an old console showed it on a
// TV. It's drawn at a low resolution and smoothly upscaled, with a little
// colour bleed, faint scanlines and darker corners. No visible pixels.
// Drawn on a canvas layer below the UI, like the pixel filter.

// Linear filtering: one lookup between four real pixels averages them.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// How many rows of low-res pixels fill the screen's height.
uniform float target_rows = 540.0;
// Colour smears sideways further than brightness, as over a TV cable:
// how far, in low-res pixels.
uniform float bleed = 0.6;
// How much each low-res row darkens between scanlines (0 = none).
uniform float scanlines = 0.06;
// How much darker the corners are than the middle.
uniform float vignette = 0.2;

// The low-res frame at `p` (in low-res pixels), blended between the four
// nearest low-res pixels: the smooth upscale a TV's blur gives.
vec3 low_res(vec2 p, float block, vec2 px_size) {
	vec2 i = floor(p - 0.5);
	vec2 f = p - 0.5 - i;
	vec3 a = texture(screen_tex, (i + vec2(0.5, 0.5)) * block * px_size).rgb;
	vec3 b = texture(screen_tex, (i + vec2(1.5, 0.5)) * block * px_size).rgb;
	vec3 c = texture(screen_tex, (i + vec2(0.5, 1.5)) * block * px_size).rgb;
	vec3 d = texture(screen_tex, (i + vec2(1.5, 1.5)) * block * px_size).rgb;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float block = max(1.0, screen_size.y / target_rows);
	vec2 p = FRAGCOORD.xy / block;
	vec3 mid = low_res(p, block, SCREEN_PIXEL_SIZE);
	vec3 left = low_res(p - vec2(bleed, 0.0), block, SCREEN_PIXEL_SIZE);
	vec3 right = low_res(p + vec2(bleed, 0.0), block, SCREEN_PIXEL_SIZE);
	// Keep the middle sample's brightness but the smeared samples' colour.
	const vec3 LUMA = vec3(0.299, 0.587, 0.114);
	vec3 smear = (left + mid * 2.0 + right) * 0.25;
	vec3 col = smear + (dot(mid, LUMA) - dot(smear, LUMA));

	// One soft dark line per low-res row, made up for with a small lift so
	// the picture isn't dimmer overall.
	col *= 1.0 + scanlines * 0.5 - scanlines * (0.5 + 0.5 * cos(p.y * 6.2831853));

	vec2 from_mid = SCREEN_UV - 0.5;
	col *= 1.0 - vignette * dot(from_mid, from_mid) * 2.0;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
