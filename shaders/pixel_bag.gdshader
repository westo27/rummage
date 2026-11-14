shader_type canvas_item;
// The marble bag in the pixel filter's style. The bag's SubViewport is already
// rendered small (MarbleBag sets stretch_shrink), so each of its texels is one
// chunky pixel; this gives them the same colour limit and dither as the 3D,
// and hard edges: a texel is either fully there or not.
#include "res://shaders/dither.gdshaderinc"

uniform float levels = 16.0;
uniform float spread = 0.5;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
	// Soft edges (antialiasing, the see-through net) become a dithered
	// on/off instead of partial see-through.
	float alpha = step(1.0 - bayer(cell), tex.a);
	COLOR = vec4(dither_quantise(tex.rgb, cell, levels, spread), alpha);
}
