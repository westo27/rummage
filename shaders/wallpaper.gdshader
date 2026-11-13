// The walls: cream wallpaper with a pattern of soft dots, a glossy white
// skirting board along the bottom, and a plain ceiling.
//
// The house's walls are one CSG shape, so there's one material for all of
// it. The shader tells the parts apart by which way each surface faces
// (ceilings face down) and how high it is (the skirting is the bottom 13 cm).
// The pattern is laid out in metres in the world, not stretched over each
// surface, so the dots are the same size everywhere.
shader_type spatial;

uniform vec3 paper : source_color = vec3(0.97, 0.92, 0.82);
uniform vec3 dot_color : source_color = vec3(0.96, 0.78, 0.58);
uniform vec3 skirting : source_color = vec3(0.99, 0.98, 0.95);
uniform vec3 ceiling : source_color = vec3(0.99, 0.96, 0.90);
// Metres between dot centres, and each dot's radius.
uniform float dot_spacing = 0.22;
uniform float dot_radius = 0.032;
uniform float skirting_height = 0.13;

varying vec3 world_pos;
varying vec3 world_normal;

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
		// A grid of dots with every other row shifted by half, like a
		// classic polka-dot paper.
		vec2 cell = p / dot_spacing;
		cell.x += mod(floor(cell.y), 2.0) * 0.5;
		float d = length(fract(cell) - 0.5) * dot_spacing;
		float dot_amount = 1.0 - smoothstep(dot_radius - 0.004, dot_radius, d);
		ALBEDO = mix(paper, dot_color, dot_amount);
		ROUGHNESS = 0.85;
	}
}
