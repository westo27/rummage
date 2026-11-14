// The walls: cream wallpaper with little gold stars, a glossy white
// skirting board along the bottom, and a plain ceiling.
//
// The house's walls are one CSG shape, so there's one material for all of
// it. The shader tells the parts apart by which way each surface faces
// (ceilings face down) and how high it is (the skirting is the bottom 13 cm).
// The pattern is laid out in metres in the world, not stretched over each
// surface, so the dots are the same size everywhere.
shader_type spatial;
#include "res://shaders/pixel_art.gdshaderinc"

uniform vec3 paper : source_color = vec3(0.97, 0.92, 0.82);
uniform vec3 star_color : source_color = vec3(0.98, 0.76, 0.36);
uniform vec3 dot_color : source_color = vec3(0.96, 0.82, 0.66);
uniform vec3 skirting : source_color = vec3(0.99, 0.98, 0.95);
uniform vec3 ceiling : source_color = vec3(0.99, 0.96, 0.90);
// Metres between star centres, each star's outer radius, and the little
// dots' radius.
uniform float star_spacing = 0.3;
uniform float star_radius = 0.055;
uniform float dot_radius = 0.012;
uniform float skirting_height = 0.13;

varying vec3 world_pos;
varying vec3 world_normal;

// A random number from 0 to 1 for each grid cell.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Signed distance to a five-pointed star pointing up (negative inside).
// `r` is the outer radius; `inner` is how fat the arms are (0-1).
// Adapted from Inigo Quilez's 2D distance functions.
float star(vec2 p, float r, float inner) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = inner * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (world_normal.y < -0.5) {
		ALBEDO = ceiling;
		ROUGHNESS = 0.9;
	} else if (world_pos.y < skirting_height) {
		// Painted wood: glossy, with a darker line along its top edge.
		float lip = smoothstep(skirting_height - 0.014, skirting_height - 0.005, world_pos.y);
		ALBEDO = skirting * mix(1.0, 0.86, lip);
		ROUGHNESS = 0.3;
	} else {
		// Lay the wall out flat: across is x on walls facing north or south,
		// z on walls facing east or west; up is height.
		vec2 p = abs(world_normal.x) > abs(world_normal.z)
			? vec2(world_pos.z, world_pos.y) : vec2(world_pos.x, world_pos.y);
		// Finer than the floor, so the little stars still have a shape.
		p = pixel_snap(p, 2.0);
		// A grid of stars with every other row shifted by half, each one
		// turned a little at random, and a tiny dot between them.
		vec2 cell = p / star_spacing;
		cell.x += mod(floor(cell.y), 2.0) * 0.5;
		vec2 id = floor(cell);
		vec2 local = (fract(cell) - 0.5) * star_spacing;
		float angle = (hash(id) - 0.5) * 0.9;
		local = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * local;
		float d = star(local, star_radius, 0.45);
		// The dot sits on the corner between four stars.
		float d_dot = length(fract(cell) - vec2(0.0, 0.0)) * star_spacing - dot_radius;
		d_dot = min(d_dot, length(fract(cell) - vec2(1.0, 0.0)) * star_spacing - dot_radius);
		d_dot = min(d_dot, length(fract(cell) - vec2(0.0, 1.0)) * star_spacing - dot_radius);
		d_dot = min(d_dot, length(fract(cell) - vec2(1.0, 1.0)) * star_spacing - dot_radius);
		float aa = pixel_edge(d);
		float star_amount = 1.0 - smoothstep(-aa, aa, d);
		float dot_amount = 1.0 - smoothstep(-aa, aa, d_dot);
		ALBEDO = mix(mix(paper, dot_color, dot_amount), star_color, star_amount);
		ROUGHNESS = 0.85;
	}
}
