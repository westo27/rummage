shader_type canvas_item;
// The marble bag in the pixel filter's style. The bag's SubViewport is already
// rendered small (MarbleBag sets stretch_shrink), so each of its texels is one
// chunky pixel; this gives them hard edges (a texel is either fully there or
// not) and, with Graphics > Dither on, the same colour limit and dither as the 3D.
#include "res://shaders/dither.gdshaderinc"

uniform bool dither = false;
uniform float levels = 16.0;
uniform float spread = 0.5;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
	if (dither) {
		// Soft edges (antialiasing, the see-through net) become a dithered
		// on/off instead of partial see-through.
		COLOR = vec4(dither_quantise(tex.rgb, cell, levels, spread), step(1.0 - bayer(cell), tex.a));
	} else {
		COLOR = vec4(tex.rgb, step(0.5, tex.a));
	}
}
