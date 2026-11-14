shader_type canvas_item;
// The chunky low-resolution look: the 3D view is redrawn in big square
// pixels, each one a single point-sampled colour from the full-res frame.
// Drawn on a canvas layer below the UI, so the screen texture holds only the
// 3D world and the menus and HUD stay crisp on top.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// How many rows of chunky pixels fill the screen's height. Each chunky pixel
// is a whole number of real pixels, so they're all the same size.
uniform float target_rows = 270.0;

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float block = max(1.0, round(screen_size.y / target_rows));
	// Sample the middle of each block, so every real pixel in it agrees.
	vec2 centre = (floor(FRAGCOORD.xy / block) + 0.5) * block;
	COLOR = vec4(texture(screen_tex, centre * SCREEN_PIXEL_SIZE).rgb, 1.0);
}
