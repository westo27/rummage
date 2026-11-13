// The grab beam's look: a white-hot core inside a soft coloured halo, with
// pulses of light running from the hand to the object and a slight flicker,
// like a live wire.
//
// A shader is a small program the graphics card runs for every pixel of the
// beam. The ribbon's UV coordinates say where a pixel is on it: UV.x goes
// across the ribbon (0 one edge, 1 the other), UV.y along it (0 at the
// hand, 1 at the object). beam.gd sets those when it builds the ribbon.
//
// It's "unshaded" (room lights don't affect it, it is the light) and
// "blend_add" (it brightens whatever is behind it rather than covering it,
// which is what makes it look like light). Values above 1.0 are brighter
// than white, and that's what the bloom picks up and spreads into a glow.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Set by beam.gd: cyan when holding, red when too heavy, the creature's colour
// when catching.
uniform vec4 beam_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
// Overall brightness. Above 1 feeds the bloom.
uniform float intensity = 2.0;
// 0 = calm, 1 = straining (too heavy): faster pulses, more flicker.
uniform float agitation = 0.0;
// 1 for the thin crackling filament: core only, no halo, no fade.
uniform float filament = 0.0;

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);  // 0 on the centre line, 1 at the edges
	float along = UV.y;

	// A thin bright core and a soft halo around it.
	float core = pow(1.0 - across, mix(7.0, 2.5, filament));
	float halo = pow(1.0 - across, 1.6) * 0.35 * (1.0 - filament);

	// Bright bands sliding from the hand toward the object.
	float speed = mix(14.0, 26.0, agitation);
	float pulse = pow(0.5 + 0.5 * sin(along * 55.0 - TIME * speed), 5.0);

	// Flicker: two fast wobbles multiplied, so it never settles into a rhythm.
	float flicker_depth = mix(0.12, 0.35, agitation);
	float flicker = 1.0 - flicker_depth + flicker_depth
		* sin(TIME * 53.0 + along * 31.0) * sin(TIME * 37.0 + along * 7.0);

	float strength = (core * (1.0 + pulse * 1.4) + halo * (0.7 + pulse * 0.5)) * flicker;
	// The hand end is just off the bottom of the screen; a tiny fade there
	// in case a wide screen shows its very tip.
	strength *= smoothstep(0.0, 0.015, along);

	// The core runs toward white, as the hottest part of a glow does.
	vec3 colour = mix(beam_color.rgb, vec3(1.0), core * 0.55);
	ALBEDO = colour * strength * intensity;
}
