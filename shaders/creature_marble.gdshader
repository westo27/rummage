// A creature as a glass marble, matching its marble in the HUD bag
// (glass_marble.gdshader): smoky glass with a little of its colour, a swirl
// in its colour, a pale thin ribbon, a few bubbles, white light round the
// edge and a highlight at the top left.
// It's opaque: the "inside" is faked by sampling the swirl partway along
// the view ray through the ball, so it shifts with the angle like real glass.
// The face is drawn on in felt-tip, as if by the child who owns the marbles:
// rough wobbly ink, loops that don't quite close, its own mix of eyes and
// mouth on every marble, and lines that "boil" (redrawn a few times a second,
// like hand-drawn animation). CreatureEyes drives it through the eye_* uniforms.
shader_type spatial;

uniform vec4 tint : source_color = vec4(0.45, 0.95, 0.4, 1.0);
// 0..1, different for each creature, so no two swirls are the same.
uniform float seed = 0.0;
// How brightly the glass glows on its own, so it reads in the dark room.
uniform float glow = 0.5;

// Which face this marble has (picked by Creature from DoodleFace, shared
// with its bag marble): the kind of eyes and mouth (see doodle_eye and
// doodle_mouth), extras as bits (see doodle_extras), and how lopsided it's
// drawn, -1..1.
uniform int face_eyes = 0;
uniform int face_mouth = 0;
uniform int face_extras = 0;
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
// `from`..`to` limits it to an arc (radians, 0 = right, anticlockwise). A
// full loop is drawn like a pen stroke: it starts at a fixed point, drifts
// slightly outward as it goes round, and carries on a little past its start,
// so the two ends overlap rather than meeting.
float ink_ring(vec2 f, vec2 c, float r, float w, float s, float from, float to) {
	float aa = fwidth(f.x) * 1.2;
	vec2 d = f - c;
	float ang = atan(d.y, d.x);
	float k = ang * 1.3 + s * 17.0;
	float rr = r * (1.0 + 0.06 * wobble(k) + 0.015 * wobble(k * 2.3));
	// Felt-tip pressure: thicker in places.
	float ww = w * (0.8 + 0.4 * (wobble(k * 1.7 + 5.0) * 0.5 + 0.5));
	float dist = length(d);
	if (to - from < 6.2) {
		float span = step(from, ang) * step(ang, to);
		return (1.0 - smoothstep(ww - aa, ww, abs(dist - rr))) * span;
	}
	// Where the pen started: fixed per marble and eye, so it doesn't jump
	// about as the ink boils.
	float start = hash(seed * 13.0 + c.x * 7.0 + c.y * 3.0) * 6.283;
	float a0 = mod(ang - start, 6.283);
	float line = 0.0;
	for (int i = 0; i < 2; i++) {
		float t = a0 + float(i) * 6.283;  // first time round, then the overlap
		if (t <= 6.283 + 0.7) {
			float rt = rr * (1.0 + 0.07 * (t / 6.283 - 0.5));
			line = max(line, 1.0 - smoothstep(ww - aa, ww, abs(dist - rt)));
		}
	}
	return line;
}

// A filled wobbly blob: an inked-in dot.
float ink_dot(vec2 f, vec2 c, vec2 r, float s) {
	float aa = fwidth(f.x) * 1.2;
	vec2 d = (f - c) / r;
	float ang = atan(d.y, d.x);
	float edge = 1.0 + 0.09 * wobble(ang * 1.5 + s * 13.0);
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

// One doodled eye; `side` is -1 for the left, 1 for the right. Kinds:
// 0 inked dot, 1 ring with a dot pupil, 2 ring and dot with lashes, 3 tall
// bean, 4 googly (big ring, small droopy pupil), 5 sleepy (half-lidded),
// 6 star, 7 heart, 8 spiral, 9 winking (the right eye a "^").
// `open` squashes it shut (blink, squint); `wide` draws it bigger. Returns
// (ink, the eye's area, which flashes when it glints).
vec2 doodle_eye(vec2 f, vec2 c, float size, float open, float wide, vec2 look, int kind, float side, float s) {
	float h = max(open, 0.05);
	vec2 g = vec2(f.x, c.y + (f.y - c.y) / h);  // squash toward the eye's middle line
	float r = 0.18 * size * (1.0 + wide * 0.3);
	float w = 0.036;
	float aa = fwidth(f.x) * 1.2;
	if (open < 0.3) {
		// Shut: just a line.
		return vec2(ink_stroke(f, c - vec2(r, 0.0), c + vec2(r, 0.0), w), 0.0);
	}
	if (kind == 9 && side > 0.0) {
		return vec2(ink_ring(f, c - vec2(0.0, 0.07), 0.16, w, s, 0.35, 2.79), 0.0);
	}
	float pupil_r = r * mix(0.55, 0.38, wide);
	vec2 pc = c + look * r * 0.45 + vec2(0.0, -r * 0.1);
	vec2 d = (g - c) / r;
	float ink = 0.0;
	vec2 dot_r = vec2(pupil_r);
	if (kind == 0) {
		dot_r = vec2(r * 0.62, r * 0.78);
		ink = ink_dot(g, pc, dot_r, s);
	} else if (kind == 3) {
		dot_r = vec2(r * 0.5, r * 1.05);
		ink = ink_dot(g, pc, dot_r, s);
	} else if (kind == 4) {
		// The pupil rattles round the bottom of a big ring.
		pc = c + look * r * 0.7 + vec2(0.0, -r * 0.6);
		dot_r = vec2(r * 0.36);
		ink = max(ink_ring(g, c, r * 1.25, w, s, -4.0, 4.0), ink_dot(g, pc, dot_r, s + 3.0));
	} else if (kind == 5) {
		// A heavy lid across the middle, the pupil peeping under it.
		pc = c + vec2(look.x * r * 0.4, -r * 0.42);
		dot_r = vec2(r * 0.42);
		float pupil = ink_dot(g, pc, dot_r, s + 3.0) * step(g.y, c.y + r * 0.05);
		ink = max(max(ink_ring(g, c, r, w, s, -3.14, 0.1), ink_stroke(g, c + vec2(-r * 1.05, r * 0.05), c + vec2(r * 1.05, r * 0.05), w)), pupil);
	} else if (kind == 6) {
		float ang = atan(d.y, d.x);
		float k = pow(0.5 + 0.5 * cos(5.0 * (ang - 1.5708)), 2.5);
		float edge = mix(0.48, 1.12, k);
		ink = 1.0 - smoothstep(edge - aa / r, edge, length(d));
		pc = c;
		dot_r = vec2(r * 0.4);
	} else if (kind == 7) {
		vec2 q = d * 1.25 + vec2(0.0, 0.25);
		float hh = pow(q.x * q.x + q.y * q.y - 1.0, 3.0) - q.x * q.x * q.y * q.y * q.y;
		ink = 1.0 - smoothstep(-0.02, 0.02, hh);
		pc = c + vec2(0.0, r * 0.1);
		dot_r = vec2(r * 0.45);
	} else if (kind == 8) {
		vec2 e = d / 1.3;
		float rr = length(e);
		float a = atan(e.y, e.x) / 6.283;
		float dist = abs(fract(rr * 1.6 - a + 0.5) - 0.5) / 1.6 * 1.3;
		float lw = w * 0.75 / r;
		ink = (1.0 - smoothstep(lw - aa / r, lw, dist)) * step(rr, 1.0);
	} else {
		ink = max(ink_ring(g, c, r, w, s, -4.0, 4.0), ink_dot(g, pc, dot_r, s + 3.0));
		if (kind == 2) {
			for (int i = 0; i < 3; i++) {
				float a = 1.15 + float(i) * 0.42;
				vec2 dir = vec2(cos(a), sin(a));
				dir.x *= -side;  // lashes flick outward on both sides
				ink = max(ink, ink_stroke(g, c + dir * r, c + dir * r * 1.55, w * 0.8));
			}
		}
	}
	float area = 1.0 - smoothstep(0.8, 1.25, length(d));
	return vec2(ink, area);
}

// The doodled mouth. Kinds: 0 smile, 1 open grin, 2 wonky smile with a
// dimple, 3 cat "w", 4 tongue out, 5 buck teeth, 6 nervous zigzag,
// 7 kissy "3", 8 toothy grin. Startled is always a little "o"; happy, a big
// grin (toothy stays toothy).
float doodle_mouth(vec2 f, int kind, float wide, float happy_amount, float s) {
	vec2 c = vec2(0.0, -0.17);
	float w = 0.028;
	if (wide > 0.5) {
		return ink_ring(f, c - vec2(0.0, 0.03), 0.045, w, s, -4.0, 4.0);
	}
	if (kind == 1 || kind == 8 || happy_amount > 0.5) {
		// Flat top and a round bottom, like a "D" on its side.
		float m = max(ink_stroke(f, c + vec2(-0.12, 0.0), c + vec2(0.12, 0.0), w), ink_ring(f, c, 0.12, w, s, -3.14, 0.0));
		if (kind == 8) {
			m = max(m, ink_stroke(f, c + vec2(-0.1, -0.05), c + vec2(0.1, -0.05), w * 0.7));
			for (int i = 0; i < 3; i++) {
				float x = -0.05 + float(i) * 0.05;
				m = max(m, ink_stroke(f, c + vec2(x, 0.0), c + vec2(x, -0.05), w * 0.7));
			}
		}
		return m;
	}
	if (kind == 2) {
		float line = ink_ring(f, c + vec2(0.0, 0.16), 0.2, w, s, -2.0, -1.15);
		return max(line, ink_stroke(f, c + vec2(0.085, -0.035), c + vec2(0.105, -0.005), w * 0.8));
	}
	if (kind == 3) {
		return max(ink_ring(f, c + vec2(-0.045, 0.02), 0.045, w, s, -3.14, 0.0),
			ink_ring(f, c + vec2(0.045, 0.02), 0.045, w, s + 1.0, -3.14, 0.0));
	}
	if (kind == 4) {
		float smile = ink_ring(f, c + vec2(0.0, 0.07), 0.1, w, s, -2.6, -0.55);
		return max(smile, ink_ring(f, c + vec2(0.03, -0.035), 0.05, w * 0.9, s + 2.0, -3.14, 0.0));
	}
	if (kind == 5) {
		float smile = ink_ring(f, c + vec2(0.0, 0.07), 0.1, w, s, -2.6, -0.55);
		vec2 t = c + vec2(0.0, -0.03);
		float teeth = max(max(ink_stroke(f, t + vec2(-0.055, 0.0), t + vec2(-0.055, -0.065), w * 0.8),
			ink_stroke(f, t, t + vec2(0.0, -0.065), w * 0.8)),
			max(ink_stroke(f, t + vec2(0.055, 0.0), t + vec2(0.055, -0.065), w * 0.8),
			ink_stroke(f, t + vec2(-0.055, -0.065), t + vec2(0.055, -0.065), w * 0.8)));
		return max(smile, teeth);
	}
	if (kind == 6) {
		float z = 0.0;
		for (int i = 0; i < 4; i++) {
			float x0 = -0.1 + float(i) * 0.05;
			float y0 = mod(float(i), 2.0) < 0.5 ? 0.0 : -0.03;
			z = max(z, ink_stroke(f, c + vec2(x0, y0 - 0.02), c + vec2(x0 + 0.05, -0.03 - y0 - 0.02), w));
		}
		return z;
	}
	if (kind == 7) {
		return max(ink_ring(f, c + vec2(-0.02, 0.02), 0.045, w, s, -1.8, 1.8),
			ink_ring(f, c + vec2(-0.02, -0.065), 0.045, w, s + 1.0, -1.8, 1.8));
	}
	return ink_ring(f, c + vec2(0.0, 0.07), 0.1, w, s, -2.6, -0.55);
}

// The extras some faces have (bits of face_extras): 1 brows, 2 nose,
// 4 freckles, 8 moustache, 16 glasses, 32 a
// tuft of hair. Returns the ink.
float doodle_extras(vec2 f, int extras, vec2 lc, vec2 rc, float s) {
	float w = 0.034;
	float ink = 0.0;
	if ((extras & 1) != 0) {
		ink = max(ink, max(ink_ring(f, lc - vec2(0.0, 0.05), 0.38, w, s, 1.27, 1.88),
			ink_ring(f, rc - vec2(0.0, 0.05), 0.38, w, s + 1.0, 1.26, 1.87)));
	}
	if ((extras & 2) != 0) {
		ink = max(ink, ink_ring(f, vec2(0.0, -0.05), 0.03, w * 0.85, s, -3.0, -0.14));
	}
	if ((extras & 4) != 0) {
		for (int i = 0; i < 3; i++) {
			vec2 o = vec2(-0.04 + float(i) * 0.04, mod(float(i), 2.0) * -0.03);
			ink = max(ink, ink_dot(f, vec2(-0.46, -0.15) + o, vec2(0.013), s + float(i)));
			ink = max(ink, ink_dot(f, vec2(0.46, -0.15) + o, vec2(0.013), s + float(i) + 5.0));
		}
	}
	if ((extras & 8) != 0) {
		ink = max(ink, max(ink_dot(f, vec2(-0.075, -0.105), vec2(0.085, 0.035), s),
			ink_dot(f, vec2(0.075, -0.105), vec2(0.085, 0.035), s + 2.0)));
		ink = max(ink, max(ink_ring(f, vec2(-0.165, -0.07), 0.045, w * 0.9, s, -3.14, -0.6),
			ink_ring(f, vec2(0.165, -0.07), 0.045, w * 0.9, s + 1.0, -2.54, 0.0)));
	}
	if ((extras & 16) != 0) {
		float gr = 0.26;
		ink = max(ink, max(ink_ring(f, lc, gr, w, s, -4.0, 4.0), ink_ring(f, rc, gr, w, s + 1.0, -4.0, 4.0)));
		ink = max(ink, ink_stroke(f, lc + vec2(gr, 0.02), rc - vec2(gr, -0.02), w));
	}
	if ((extras & 32) != 0) {
		ink = max(ink, max(ink_stroke(f, vec2(-0.05, 0.4), vec2(-0.09, 0.5), w),
			max(ink_stroke(f, vec2(0.0, 0.41), vec2(0.0, 0.53), w), ink_stroke(f, vec2(0.05, 0.4), vec2(0.09, 0.5), w))));
	}
	return ink;
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
		float lop = face_lop * 0.2;
		vec2 wide = clamp((1.0 - pupil_size) / 0.4, 0.0, 1.0);
		vec2 lc = vec2(-0.3, 0.08 + lop * 0.1);
		vec2 rc = vec2(0.3, 0.08 - lop * 0.1);
		vec2 le = doodle_eye(f, lc, eye_size.x * (1.0 + lop), eye_height.x, wide.x, pupil_offset.xy, face_eyes, -1.0, s);
		vec2 re = doodle_eye(f, rc, eye_size.y * (1.0 - lop), eye_height.y, wide.y, pupil_offset.zw, face_eyes, 1.0, s + 1.0);
		float eyes = max(le.x, re.x) * (1.0 - happy);
		float flash = max(le.y, re.y) * (1.0 - happy);
		float arcs = max(ink_ring(f, lc - vec2(0.0, 0.07), 0.16, 0.036, s, 0.35, 2.79),
			ink_ring(f, rc - vec2(0.0, 0.07), 0.16, 0.036, s + 1.0, 0.35, 2.79)) * happy;
		// Drawn 1.3x size and a little lower, to sit with the big eyes.
		vec2 fm = vec2(0.0, -0.17) + (f - vec2(0.0, -0.21)) / 1.3;
		float m = doodle_mouth(fm, face_mouth, max(wide.x, wide.y) * (1.0 - happy), happy, s + 2.0);
		float extras = doodle_extras(f, face_extras, lc, rc, s + 3.0);
		// Felt-tip on glass: dark blue-black.
		float line = max(max(max(eyes, arcs), m), extras);
		col = mix(col, vec3(0.03, 0.02, 0.09), line);
		emit = mix(emit, vec3(0.0), line * 0.9);
		// A glint (white_glow above its resting level) lights the glass round
		// the eyes, enough for the bloom: two eyes shining from hiding.
		emit += vec3(1.0) * flash * (1.0 - line) * max(white_glow - 0.35, 0.0) * 2.0;
		paint = line;
	}

	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = mix(0.12, 0.8, paint);
	SPECULAR = mix(0.35, 0.1, paint);
}
