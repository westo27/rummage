// The main room's floor: warm oak planks with dark gaps between them, each
// plank a slightly different shade, with fine grain along it and a soft
// varnish sheen. Laid out in metres in the world.
shader_type spatial;
#include "res://shaders/pixel_art.gdshaderinc"

uniform vec3 wood_light : source_color = vec3(0.88, 0.63, 0.38);
uniform vec3 wood_dark : source_color = vec3(0.72, 0.47, 0.26);
uniform vec3 gap_color : source_color = vec3(0.40, 0.25, 0.14);
uniform float plank_width = 0.20;
uniform float plank_length = 1.6;

varying vec3 world_pos;

// A repeatable "random" number from a position: the same plank always gets
// the same shade.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = pixel_snap(world_pos.xz, 1.0);
	// Rows of planks run along x. Each row's joins are shifted by a random
	// amount, so they don't line up across the room.
	float row = floor(xz.y / plank_width);
	float along = (xz.x + hash(vec2(row, 3.1)) * plank_length) / plank_length;
	float plank = floor(along);
	float shade = hash(vec2(row, plank));
	vec3 wood = mix(wood_dark, wood_light, 0.35 + 0.65 * shade);
	float grain = 0.5 + 0.5 * sin(xz.x * 40.0 + shade * 20.0 + sin(xz.y * 30.0) * 1.5);
	if (pixel_art()) {
		grain = floor(grain * 2.99) * 0.5;  // three flat shades instead of a smooth ripple
	}
	wood *= 0.94 + 0.06 * grain;

	// Thin dark gaps along each plank's sides and ends.
	float side = fract(xz.y / plank_width) * plank_width;
	float end = fract(along) * plank_length;
	float edge = min(min(side, plank_width - side), min(end, plank_length - end));
	// As pixel art the gap is one texel wide, or it would fall between texels.
	float gap = pixel_art() ? 0.75 / pixel_texels : 0.006;
	ALBEDO = mix(gap_color, wood, smoothstep(gap * 0.5, gap, edge));
	ROUGHNESS = 0.42;
}
