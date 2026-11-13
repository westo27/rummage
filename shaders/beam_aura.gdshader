// The glowing aura the beam puts around whatever it's holding: a soft blob of
// light in the beam's colour, bigger than the object, gently wobbling and
// pulsing, glowing out from behind it.
//
// It's drawn on an ellipsoid fitted round the object (prop.gd makes it).
// Only the ellipsoid's far side is drawn (cull_front), so the object sits in
// front of it and hides its middle. What shows is a halo around the object's
// silhouette: brightest close in, fading to nothing at the blob's edge.
shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_draw_never, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
// How much the blob's surface ripples in and out (as a share of its size).
uniform float wobble = 0.05;
// Brighter than white in the middle, so the bloom spreads it.
uniform float intensity = 1.3;

void vertex() {
	// A slow ripple travelling over the surface, so the blob breathes and
	// bulges rather than being a perfect ellipse.
	float ripple = sin(VERTEX.x * 9.0 + TIME * 4.0) * sin(VERTEX.y * 8.0 - TIME * 3.3)
		* sin(VERTEX.z * 7.0 + TIME * 2.7);
	VERTEX += NORMAL * wobble * ripple;
}

void fragment() {
	// Seen straight on (the middle of the blob, behind the object) it's
	// brightest; seen edge-on (the blob's outline) it fades to nothing.
	float facing = abs(dot(NORMAL, VIEW));
	float glow = pow(facing, 1.6);
	float pulse = 0.85 + 0.15 * sin(TIME * 6.0);
	ALBEDO = glow_color.rgb * intensity * glow * pulse;
}
