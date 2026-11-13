// A soft round glow that always faces the camera: where the beam meets the
// object. Brighter than white in the middle, so the bloom spreads it.
shader_type spatial;
// depth_test_disabled: drawn even where the object's surface would hide it,
// because the glow sits right on that surface.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float intensity = 3.5;

void vertex() {
	// Turn the quad to face the camera (a billboard): keep its position but
	// take the camera's rotation.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);  // 0 in the middle, 1 at the edge
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), 3.0);
	float flicker = 0.85 + 0.15 * sin(TIME * 41.0) * sin(TIME * 23.0);
	ALBEDO = mix(glow_color.rgb, vec3(1.0), glow * 0.6) * glow * intensity * flicker;
}
