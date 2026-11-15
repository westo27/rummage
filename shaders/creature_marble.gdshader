// A creature as a glass marble, matching its marble in the HUD bag
// (glass_marble.gdshader): smoky glass with a little of its colour, a swirl
// in its colour, a pale thin ribbon, a few bubbles, white light round the
// edge and a highlight at the top left. The eyes are painted flat on the
// ball here too, driven by CreatureEyes through the eye_* uniforms.
// It's opaque: the "inside" is faked by sampling the swirl partway along
// the view ray through the ball, so it shifts with the angle like real glass.
shader_type spatial;

uniform vec4 tint : source_color = vec4(0.45, 0.95, 0.4, 1.0);
// 0..1, different for each creature, so no two swirls are the same.
uniform float seed = 0.0;
// How brightly the glass glows on its own, so it reads in the dark room.
uniform float glow = 0.5;

// Per eye (x left, y right): size, height (0 shut .. 1 open), pupil size.
uniform vec2 eye_size = vec2(1.0);
uniform vec2 eye_height = vec2(1.0);
uniform vec2 pupil_size = vec2(1.0);
// Where each pupil looks, -1..1 across the white (xy left eye, zw right).
uniform vec4 pupil_offset = vec4(0.0);
// 1 shows the happy ^ ^ arcs in place of the eyes.
uniform float happy = 0.0;
// How brightly the whites glow (they glint from hiding).
uniform float white_glow = 0.35;

// The face as seen head-on, as on the bag's marble: eye centres and radii
// in units of the ball's radius.
const vec2 EYE_CENTRE = vec2(0.36, 0.18);
const float EYE_RADIUS = 0.3;
const float PUPIL_RADIUS = 0.15;

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

// Shades one eye; f is the point on the face, c its centre. Returns
// (colour, how much eye covers here) and adds its glow to `emit`.
vec4 eye(vec2 f, vec2 c, float size, float height, float psize, vec2 look, inout vec3 emit) {
	float aa = fwidth(f.x) * 1.5;
	vec2 d = (f - c) / vec2(size, size * max(height, 0.02));
	float white = 1.0 - smoothstep(EYE_RADIUS - aa, EYE_RADIUS, length(d));
	vec2 pc = look * (EYE_RADIUS - PUPIL_RADIUS * psize) + vec2(0.0, -0.07 * psize);
	float pr = PUPIL_RADIUS * psize;
	float pupil = (1.0 - smoothstep(pr - aa, pr, length(d - pc))) * step(0.01, psize);
	float spark = 1.0 - smoothstep(pr * 0.22 - aa, pr * 0.22, length(d - pc - vec2(-0.35, 0.35) * pr));
	spark *= pupil;
	vec3 col = mix(vec3(1.0), vec3(0.02), pupil);
	col = mix(col, vec3(1.0), spark);
	emit += white * ((1.0 - pupil) * white_glow + spark) * vec3(1.0);
	return vec4(col, white);
}

// The "^" of a happy, squeezed-shut eye.
float arc(vec2 f, vec2 c) {
	float aa = fwidth(f.x) * 1.5;
	vec2 d = (f - c - vec2(0.0, -0.04)) / vec2(1.0, 0.8);
	float r = 0.19;
	float ang = atan(d.y, d.x);
	float on_arc = step(0.35, ang) * step(ang, 2.79);
	float line = 1.0 - smoothstep(0.06 - aa, 0.06, abs(length(d) - r));
	// Round ends.
	vec2 e1 = vec2(cos(0.35), sin(0.35)) * r * vec2(1.0, 1.0);
	vec2 e2 = vec2(cos(2.79), sin(2.79)) * r;
	float ends = max(1.0 - smoothstep(0.06 - aa, 0.06, length(d - e1)),
		1.0 - smoothstep(0.06 - aa, 0.06, length(d - e2)));
	return max(line * on_arc, ends);
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

	// The face, painted flat on the front of the ball. Paint isn't glossy,
	// so the pupils stay black whatever the glass reflects.
	float paint = 0.0;
	if (p.z < 0.0) {
		vec2 f = vec2(p.x, p.y);
		vec3 eye_emit = vec3(0.0);
		vec4 l = eye(f, vec2(-EYE_CENTRE.x, EYE_CENTRE.y), eye_size.x, eye_height.x, pupil_size.x, pupil_offset.xy, eye_emit);
		vec4 r = eye(f, EYE_CENTRE, eye_size.y, eye_height.y, pupil_size.y, pupil_offset.zw, eye_emit);
		float cover = max(l.a, r.a) * (1.0 - happy);
		col = mix(col, l.rgb * l.a + r.rgb * r.a, cover);
		emit = mix(emit, eye_emit, cover);
		float arcs = max(arc(f, vec2(-EYE_CENTRE.x, EYE_CENTRE.y)), arc(f, EYE_CENTRE)) * happy;
		col = mix(col, vec3(0.02), arcs);
		emit = mix(emit, vec3(0.0), arcs);
		paint = max(cover, arcs);
	}

	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = mix(0.12, 0.8, paint);
	SPECULAR = mix(0.35, 0.1, paint);
}
