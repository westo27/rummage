// A creature as a glass marble, matching its marble in the HUD bag
// (glass_marble.gdshader): smoky glass with a little of its colour, a swirl
// in its colour, a pale thin ribbon, a few bubbles, white light round the
// edge and a highlight at the top left.
// It's opaque: the "inside" is faked by sampling the swirl partway along
// the view ray through the ball, so it shifts with the angle like real glass.
// The face is drawn on in felt-tip, as if by the child who owns the marbles:
// wobbly ink, its own mix of eyes and mouth on every marble, pencil-scribbled
// cheeks, and lines that "boil" (redrawn a few times a second, like hand-drawn
// animation). CreatureEyes drives it through the eye_* uniforms.
shader_type spatial;

uniform vec4 tint : source_color = vec4(0.45, 0.95, 0.4, 1.0);
// 0..1, different for each creature, so no two swirls are the same.
uniform float seed = 0.0;
// How brightly the glass glows on its own, so it reads in the dark room.
uniform float glow = 0.5;

// Which face this marble has (picked by Creature, shared with its bag
// marble): eyes 0 dots, 1 rings, 2 rings with lashes; mouth 0 smile, 1 open
// grin, 2 wonky smile; and how lopsided it's drawn, -1..1.
uniform int face_eyes = 0;
uniform int face_mouth = 0;
uniform float face_lop = 0.0;
// Per eye (x left, y right): size, height (0 shut .. 1 open), pupil size
// (under 1 when wide-eyed).
uniform vec2 eye_size = vec2(1.0);
uniform vec2 eye_height = vec2(1.0);
uniform vec2 pupil_size = vec2(1.0);
// Where each pupil looks, -1..1 (xy left eye, zw right).
uniform vec4 pupil_offset = vec4(0.0);
// 1 shows the happy ^ ^ arcs in place of the eyes.
uniform float happy = 0.0;
// How brightly the highlights in the pupils shine (they glint from hiding).
uniform float white_glow = 0.35;

varying vec3 obj_pos;
varying vec3 obj_cam;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

vec3 rand_dir(float s) {
	float z = hash(s) * 2.0 - 1.0;
	float a = hash(s + 0.5) * 6.283;
	float r = sqrt(1.0 - z * z);
	return vec3(r * cos(a), r * sin(a), z);
}

// A soft wavy sheet through the ball: 1 on its centre.
float ribbon(vec3 q, float s, float width) {
	vec3 n = rand_dir(s);
	vec3 a = normalize(cross(n, rand_dir(s + 0.2)));
	float ph = s * 6.283;
	float along = dot(q, a);
	float h = dot(q, n) - 0.25 * sin(along * 2.5 + ph) - mix(-0.2, 0.2, hash(s + 0.6));
	float w = width * (0.6 + 0.6 * abs(cos(along * 2.0 + ph)));
	return 1.0 - smoothstep(w * 0.3, w, abs(h));
}

void vertex() {
	obj_pos = VERTEX;
	obj_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

// Smooth 1D noise, -1..1.
float wobble(float x) {
	float i = floor(x);
	float t = fract(x);
	t = t * t * (3.0 - 2.0 * t);
	return mix(hash(i), hash(i + 1.0), t) * 2.0 - 1.0;
}

// A hand-drawn ink line along a wobbly circle: radius r, thickness w.
// `from`..`to` limits it to an arc (radians, 0 = right, anticlockwise).
float ink_ring(vec2 f, vec2 c, float r, float w, float s, float from, float to) {
	float aa = fwidth(f.x) * 1.2;
	vec2 d = f - c;
	float ang = atan(d.y, d.x);
	float k = ang * 1.3 + s * 17.0;
	float rr = r * (1.0 + 0.07 * wobble(k) + 0.03 * wobble(k * 3.1));
	// Felt-tip pressure: thicker in places.
	float ww = w * (0.8 + 0.35 * (wobble(k * 1.7 + 5.0) * 0.5 + 0.5));
	float line = 1.0 - smoothstep(ww - aa, ww, abs(length(d) - rr));
	float span = step(from, ang) * step(ang, to);
	return line * (to - from > 6.2 ? 1.0 : span);
}

// A filled wobbly blob: an inked-in dot.
float ink_dot(vec2 f, vec2 c, vec2 r, float s) {
	float aa = fwidth(f.x) * 1.2;
	vec2 d = (f - c) / r;
	float ang = atan(d.y, d.x);
	float edge = 1.0 + 0.1 * wobble(ang * 1.5 + s * 13.0);
	return 1.0 - smoothstep(edge - aa / r.x, edge, length(d));
}

// A short straight ink stroke from a to b.
float ink_stroke(vec2 f, vec2 a, vec2 b, float w) {
	float aa = fwidth(f.x) * 1.2;
	vec2 pa = f - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return 1.0 - smoothstep(w - aa, w, length(pa - ba * h));
}

// One doodled eye. kind 0: an inked dot. 1: a ring with a dot pupil.
// 2: a ring and dot with three lashes. `open` squashes it shut (blink,
// squint); `wide` draws it bigger with a smaller pupil. Returns (ink, the
// little highlight left blank in the pupil, which is what glints).
vec2 doodle_eye(vec2 f, vec2 c, float size, float open, float wide, vec2 look, int kind, float s) {
	float h = max(open, 0.05);
	vec2 g = vec2(f.x, c.y + (f.y - c.y) / h);  // squash toward the eye's middle line
	float r = 0.11 * size * (1.0 + wide * 0.35);
	float w = 0.03;
	if (open < 0.3) {
		// Shut: just a line.
		return vec2(ink_stroke(f, c - vec2(r, 0.0), c + vec2(r, 0.0), w), 0.0);
	}
	float pupil_r = r * mix(0.55, 0.38, wide);
	vec2 pc = c + look * r * 0.45 + vec2(0.0, -r * 0.1);
	vec2 dot_r = kind == 0 ? vec2(r * 0.62, r * 0.78) : vec2(pupil_r);
	float spark = ink_dot(g, pc + vec2(-0.32, 0.36) * dot_r, dot_r * 0.3, s + 7.0);
	if (kind == 0) {
		return vec2(ink_dot(g, pc, dot_r, s) * (1.0 - spark), spark);
	}
	float eye = max(ink_ring(g, c, r, w, s, -4.0, 4.0), ink_dot(g, pc, vec2(pupil_r), s + 3.0));
	if (kind == 2) {
		for (int i = 0; i < 3; i++) {
			float a = 1.15 + float(i) * 0.42;
			vec2 dir = vec2(cos(a), sin(a));
			if (c.x < 0.0) {
				dir.x = -dir.x;  // lashes flick outward on both sides
			}
			eye = max(eye, ink_stroke(g, c + dir * r, c + dir * r * 1.55, w * 0.8));
		}
	}
	return vec2(eye * (1.0 - spark), spark);
}

// The doodled mouth. kind 0: a smile. 1: an open grin, outlined. 2: a
// wonky line with a dimple. Startled is always a little "o"; happy, a big grin.
float doodle_mouth(vec2 f, int kind, float wide, float happy_amount, float s) {
	vec2 c = vec2(0.0, -0.17);
	float w = 0.028;
	if (wide > 0.5) {
		return ink_ring(f, c - vec2(0.0, 0.03), 0.045, w, s, -4.0, 4.0);
	}
	if (happy_amount > 0.5 || kind == 1) {
		// Flat top and a round bottom, like a "D" on its side.
		float top = ink_stroke(f, c + vec2(-0.12, 0.0), c + vec2(0.12, 0.0), w);
		return max(top, ink_ring(f, c, 0.12, w, s, -3.14, 0.0));
	}
	if (kind == 2) {
		float line = ink_ring(f, c + vec2(0.0, 0.16), 0.2, w, s, -2.0, -1.15);
		return max(line, ink_stroke(f, c + vec2(0.085, -0.035), c + vec2(0.105, -0.005), w * 0.8));
	}
	return ink_ring(f, c + vec2(0.0, 0.07), 0.1, w, s, -2.6, -0.55);
}

// Pink pencil scribbled in a patch: the cheeks.
float scribble(vec2 f, vec2 c, vec2 r, float s) {
	float inside = 1.0 - smoothstep(0.75, 1.0, length((f - c) / r));
	float lines = smoothstep(0.42, 0.1, abs(fract((f.x * 0.8 + f.y) * 30.0 + wobble(f.y * 30.0 + s) * 0.3) - 0.5));
	return inside * lines;
}

void fragment() {
	// The ball as a unit sphere in its own space: the face looks down -Z.
	vec3 p = normalize(obj_pos);
	vec3 into = normalize(obj_pos - obj_cam);
	// Partway along the chord through the ball, seen through the glass.
	float chord = max(-2.0 * dot(p, into), 0.0);
	vec3 q1 = p + into * chord * 0.35;
	vec3 q2 = p + into * chord * 0.6;

	vec3 smoke = mix(vec3(0.16, 0.18, 0.24), tint.rgb, 0.55);
	// Lighter on top, like the bag's marble.
	vec3 col = smoke * mix(0.75, 1.25, p.y * 0.5 + 0.5);
	float s1 = max(ribbon(q1, seed, 0.45), ribbon(q2, seed, 0.45) * 0.8);
	float s2 = ribbon(q1, seed + 0.37, 0.09);
	float s3 = ribbon(q2, seed + 0.71, 0.06);
	col = mix(col, tint.rgb * 1.1, s1);
	col = mix(col, vec3(0.95, 0.97, 1.0), s2 * 0.6);
	col = mix(col, tint.rgb * 1.3 + 0.15, s3 * 0.7);
	float bubbles = 0.0;
	for (int i = 0; i < 4; i++) {
		vec3 c = (vec3(hash(seed + float(i) * 1.1), hash(seed + float(i) * 2.3 + 5.0), hash(seed + float(i) * 4.1 + 2.0)) - 0.5) * 1.1;
		float rad = 0.04 + 0.04 * hash(seed + float(i) * 3.7);
		bubbles = max(bubbles, 1.0 - smoothstep(rad * 0.5, rad, length(q1 - c)));
	}
	col = mix(col, vec3(0.9, 0.95, 1.0), bubbles * 0.7);
	vec3 emit = col * glow;

	// Edge light, brighter toward the upper left of the screen.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.3, 0.08, facing);
	float lit = clamp(dot(normalize(NORMAL.xy + 1e-4), vec2(-0.707, 0.707)) * 0.5 + 0.5, 0.0, 1.0);
	float rim_amount = rim * (0.45 + 0.55 * lit);
	col = mix(col, vec3(1.0), rim_amount * 0.7);
	emit += vec3(1.0) * rim_amount * 0.35;
	// A sharp highlight at the top left, as on the bag's marble.
	float glint = smoothstep(0.985, 0.993, dot(NORMAL, normalize(vec3(-0.45, 0.55, 0.7))));
	col = mix(col, vec3(1.0), glint * 0.9);
	emit += vec3(1.0) * glint * 0.25;

	// The face, on the front of the ball. Ink isn't glossy, so it stays dark
	// whatever the glass reflects.
	float paint = 0.0;
	if (p.z < 0.0) {
		// Redrawn a little differently six times a second: the ink boils.
		float s = seed * 31.0 + floor(TIME * 6.0) * 0.37;
		vec2 f = vec2(p.x, p.y) / 1.45;
		float lop = face_lop * 0.125;
		vec2 wide = clamp((1.0 - pupil_size) / 0.4, 0.0, 1.0);
		vec2 lc = vec2(-0.25, 0.06 + lop * 0.1);
		vec2 rc = vec2(0.25, 0.06 - lop * 0.1);
		vec2 le = doodle_eye(f, lc, eye_size.x * (1.0 + lop), eye_height.x, wide.x, pupil_offset.xy, face_eyes, s);
		vec2 re = doodle_eye(f, rc, eye_size.y * (1.0 - lop), eye_height.y, wide.y, pupil_offset.zw, face_eyes, s + 1.0);
		float eyes = max(le.x, re.x) * (1.0 - happy);
		float spark = max(le.y, re.y) * (1.0 - happy);
		float arcs = max(ink_ring(f, lc - vec2(0.0, 0.05), 0.1, 0.03, s, 0.35, 2.79),
			ink_ring(f, rc - vec2(0.0, 0.05), 0.1, 0.03, s + 1.0, 0.35, 2.79)) * happy;
		float m = doodle_mouth(f, face_mouth, max(wide.x, wide.y) * (1.0 - happy), happy, s + 2.0);
		float cheeks = max(scribble(f, vec2(-0.42, -0.12), vec2(0.1, 0.065), s),
			scribble(f, vec2(0.42, -0.12), vec2(0.1, 0.065), s + 4.0));
		// Felt-tip on glass: dark blue-black.
		float line = max(max(eyes, arcs), m);
		col = mix(col, vec3(1.0, 0.42, 0.55), cheeks);
		col = mix(col, vec3(0.03, 0.02, 0.09), line);
		col = mix(col, vec3(1.0), spark);
		emit = mix(emit, vec3(0.0), line * 0.9);
		emit = mix(emit, vec3(1.0, 0.3, 0.45) * 0.15, cheeks);
		// The highlights catch the light: enough for the bloom when glinting.
		emit += vec3(1.0) * spark * white_glow * 2.5;
		paint = max(line, cheeks * 0.5);
	}

	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = mix(0.12, 0.8, paint);
	SPECULAR = mix(0.35, 0.1, paint);
}
