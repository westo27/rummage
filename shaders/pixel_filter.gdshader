shader_type canvas_item;
// The chunky low-resolution look: the 3D view is redrawn in big square
// pixels, each one a single point-sampled colour from the full-res frame,
// limited to a few shades per channel with a dither between them.
// Drawn on a canvas layer below the UI, so the screen texture holds only the
// 3D world and the menus and HUD stay crisp on top.
#include "res://shaders/dither.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// How many rows of chunky pixels fill the screen's height. Each chunky pixel
// is a whole number of real pixels, so they're all the same size.
uniform float target_rows = 270.0;
// Shades per colour channel, and how much of each band is dithered (see
// dither.gdshaderinc). The marble bag uses the same defaults.
uniform float levels = 16.0;
uniform float spread = 0.5;

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float block = max(1.0, round(screen_size.y / target_rows));
	// Sample the middle of each block, so every real pixel in it agrees.
	vec2 cell = floor(FRAGCOORD.xy / block);
	vec3 col = texture(screen_tex, (cell + 0.5) * block * SCREEN_PIXEL_SIZE).rgb;
	// Dithered per chunky pixel, so the pattern is as big as the pixels.
	COLOR = vec4(dither_quantise(col, cell, levels, spread), 1.0);
}
