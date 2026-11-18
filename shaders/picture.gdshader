// A child's picture in a frame: one of three simple scenes, painted in UV
// space on the canvas. `art` picks which: 0 sunny hills, 1 moon and stars,
// 2 rainbow.
shader_type spatial;
uniform int art = 0;
float circle(vec2 p, vec2 c, float r) {
	float soft = 0.01;
	return 1.0 - smoothstep(r - soft, r + soft, length(p - c));
}

void fragment() {
	vec2 p = vec2(UV.x, 1.0 - UV.y);  // y up
	vec3 col;
	if (art == 0) {
		col = mix(vec3(0.62, 0.84, 1.0), vec3(0.85, 0.94, 1.0), p.y);
		col = mix(col, vec3(1.0, 0.82, 0.2), circle(p, vec2(0.75, 0.75), 0.12));
		float hill1 = step(p.y, 0.32 + 0.08 * sin(p.x * 6.0));
		float hill2 = step(p.y, 0.22 + 0.06 * sin(p.x * 9.0 + 2.0));
		col = mix(col, vec3(0.45, 0.78, 0.3), hill1);
		col = mix(col, vec3(0.3, 0.62, 0.22), hill2);
	} else if (art == 1) {
		col = mix(vec3(0.08, 0.1, 0.3), vec3(0.18, 0.2, 0.45), p.y);
		float moon = circle(p, vec2(0.3, 0.68), 0.14) - circle(p, vec2(0.37, 0.72), 0.12);
		col = mix(col, vec3(1.0, 0.95, 0.7), clamp(moon, 0.0, 1.0));
		vec2 cell = floor(p * 9.0);
		float rnd = fract(sin(dot(cell, vec2(12.9, 78.2))) * 43758.5);
		float star = step(0.82, rnd) * circle(fract(p * 9.0), vec2(0.5), 0.07);
		col = mix(col, vec3(1.0, 0.95, 0.6), star);
	} else {
		col = vec3(0.95, 0.96, 0.98);
		float d = length(p - vec2(0.5, 0.1));
		vec3 bands[6] = vec3[](vec3(0.93, 0.25, 0.3), vec3(1.0, 0.6, 0.2), vec3(1.0, 0.88, 0.3),
			vec3(0.4, 0.8, 0.35), vec3(0.3, 0.6, 0.95), vec3(0.6, 0.4, 0.85));
		for (int i = 0; i < 6; i++) {
			float r = 0.62 - float(i) * 0.06;
			if (d < r && d > r - 0.06) {
				col = bands[i];
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = 0.6;
}
