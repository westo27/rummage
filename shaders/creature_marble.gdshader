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
// 0 round whites with pupils. 1 glossy black bead eyes, 2 tiny dot eyes,
// 3 big sparkly eyes: those three with blush and a little mouth. 4 and 5
// cat's-eye marbles: glowing eyes floating inside the glass, seen through
// it, with a slit pupil (4) or a round one (5). 6 a friendly grin: outlined
// eyes with big pupils, low and wide, over a big open smile.
uniform int face_style = 0;

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
float arc(vec2 f, vec2 c, float scale) {
	float aa = fwidth(f.x) * 1.5 / scale;
	vec2 d = (f - c - vec2(0.0, -0.04 * scale)) / (vec2(1.0, 0.8) * scale);
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


// A solid glossy eye with no white: dark, lit from below with a little of
// the body's colour, two highlights. `r` is its radii; `wide` 0..1 grows
// the shine. Returns (colour, how much eye covers here).
vec4 bead(vec2 f, vec2 c, vec2 r, float height, vec2 look, float wide, inout vec3 emit) {
	float aa = fwidth(f.x) * 1.5;
	vec2 rr = r * vec2(1.0, max(height, 0.02));
	vec2 d = (f - c - look * r * 0.25) / rr;
	float cover = 1.0 - smoothstep(1.0 - aa / rr.x, 1.0, length(d));
	vec3 col = mix(vec3(0.015, 0.01, 0.03), tint.rgb * 0.55, smoothstep(0.1, -1.0, d.y) * 0.85);
	float open = step(0.35, height);
	float big = mix(0.3, 0.38, wide);
	float h1 = 1.0 - smoothstep(big - aa / rr.x, big, length(d - vec2(-0.3, 0.4)));
	float h2 = 1.0 - smoothstep(0.14 - aa / rr.x, 0.14, length(d - vec2(0.38, -0.42)));
	float h3 = (1.0 - smoothstep(0.08 - aa / rr.x, 0.08, length(d - vec2(0.05, 0.62)))) * wide;
	float shine = max(max(h1, h2 * 0.9), h3) * open;
	col = mix(col, vec3(1.0), shine);
	emit += cover * shine * (0.4 + white_glow) * vec3(1.0);
	return vec4(col, cover);
}

// Soft round 0..1 patch, radii r.
float patch(vec2 f, vec2 c, vec2 r) {
	return 1.0 - smoothstep(0.55, 1.0, length((f - c) / r));
}

// The little mouth: a smile, or a small "o" when wide-eyed.
float mouth(vec2 f, float wide, float scale) {
	float aa = fwidth(f.x) * 1.5;
	vec2 c = vec2(0.0, -0.17 * scale);
	if (wide > 0.5) {
		return 1.0 - smoothstep(1.0 - aa / 0.04, 1.0, length((f - c) / vec2(0.04, 0.05) / scale));
	}
	vec2 d = f - c - vec2(0.0, 0.05 * scale);
	float ring = 1.0 - smoothstep(0.016 - aa, 0.016, abs(length(d) - 0.055 * scale));
	return ring * step(d.y, -0.022 * scale);
}

// One eye floating inside the glass, like the vane of a cat's-eye marble:
// the view ray, bent as it enters the ball at `p`, is traced to a small
// glowing ball (squashed by `height` as it blinks). Returns (colour, how
// much eye covers here) and adds its glow to `emit`.
vec4 glass_eye(vec3 p, vec3 dir, vec3 c, float radius, float height, float wide, vec2 look, bool slit, inout vec3 emit) {
	vec3 scale = vec3(radius, radius * max(height, 0.03), radius);
	vec3 o = (p - c) / scale;
	vec3 d = dir / scale;
	float a = dot(d, d);
	float b = dot(o, d);
	float disc = b * b - a * (dot(o, o) - 1.0);
	if (disc <= 0.0) {
		return vec4(0.0);
	}
	vec3 n = o + d * ((-b - sqrt(disc)) / a);
	// Soft edge from how close the ray came to missing.
	float cover = smoothstep(0.0, 0.08 * a, disc);
	vec2 e = n.xy;
	float r = length(e);
	// Amber, like a cat's, with a touch of the body's colour; darker at the rim.
	vec3 amber = mix(vec3(0.95, 0.42, 0.04), tint.rgb, 0.15);
	vec3 iris = mix(amber, vec3(1.0, 0.8, 0.3), smoothstep(0.7, 0.0, r) * 0.7);
	iris = mix(iris, amber * 0.45, smoothstep(0.78, 1.0, r));
	vec2 pr = slit ? vec2(mix(0.16, 0.5, wide), 0.82) : vec2(mix(0.38, 0.55, wide));
	float pupil = 1.0 - smoothstep(0.9, 1.0, length((e - look * 0.35 - vec2(0.0, -0.05)) / pr));
	float spark = 1.0 - smoothstep(0.15, 0.2, length(e - vec2(-0.32, 0.38)));
	spark = max(spark, (1.0 - smoothstep(0.06, 0.09, length(e - vec2(0.3, -0.35)))) * 0.8);
	spark *= step(0.35, height);
	vec3 col = mix(iris, vec3(0.0), pupil);
	col = mix(col, vec3(1.0), spark);
	emit += cover * (iris * (1.0 - pupil) * (0.05 + white_glow * 0.5) + spark * vec3(0.6));
	return vec4(col, cover);
}

// Inside an ellipse centred `c` with radii `r`, antialiased: 0..1.
float blob(vec2 f, vec2 c, vec2 r) {
	float aa = fwidth(f.x) * 1.5;
	vec2 d = (f - c) / r;
	return 1.0 - smoothstep(1.0 - aa / min(r.x, r.y), 1.0, length(d));
}

// The grin face's eye: an outlined white, a big dark pupil sitting low and
// a little inward (so it looks at you), two highlights. Returns (colour,
// cover); its whites add to `emit` so they still read in the dark.
vec4 grin_eye(vec2 f, vec2 c, float size, float height, float psize, vec2 look, float inward, inout vec3 emit) {
	vec2 r = vec2(0.13, 0.17) * size * vec2(1.0, max(height, 0.03));
	float line = 0.024;
	float outer = blob(f, c, r + line);
	float white = blob(f, c, r);
	float pr = mix(0.085, 0.108, clamp(psize, 0.0, 1.0)) * size;
	vec2 pc = c + vec2(inward * 0.02, -0.03 * size) + look * r * 0.45;
	float pupil = blob(f, pc, vec2(pr, pr * 1.12)) * white;
	float spark = max(blob(f, pc + vec2(-0.4, 0.42) * pr, vec2(0.36 * pr)),
		blob(f, pc + vec2(0.42, -0.4) * pr, vec2(0.16 * pr)) * 0.9) * pupil * step(0.35, height);
	vec3 col = vec3(0.12, 0.04, 0.1);  // the outline
	col = mix(col, vec3(1.0, 0.99, 0.96), white);
	col = mix(col, vec3(0.05, 0.03, 0.08), pupil);
	col = mix(col, vec3(1.0), spark);
	emit += white * ((1.0 - pupil) * white_glow + spark) * vec3(1.0);
	return vec4(col, outer);
}

// The grin's mouth: a big open "D" smile with a tongue, or a little "o"
// when startled. Returns (colour, cover).
vec4 grin_mouth(vec2 f, float wide, float happy_amount) {
	vec3 lip = vec3(0.12, 0.04, 0.1);
	if (wide > 0.5) {
		vec2 c = vec2(0.0, -0.21);
		float o = blob(f, c, vec2(0.065, 0.08));
		float inside = blob(f, c, vec2(0.045, 0.06));
		return vec4(mix(lip, vec3(0.38, 0.05, 0.1), inside), o);
	}
	float grow = 1.0 + happy_amount * 0.15;
	vec2 c = vec2(0.0, -0.15);
	vec2 r = vec2(0.15, 0.14) * grow;
	float top = 1.0 - smoothstep(-0.006, 0.006, f.y - c.y);  // flat top edge
	float outer = blob(f, c, r + 0.022) * (1.0 - smoothstep(-0.006, 0.006, f.y - c.y - 0.022));
	float inside = blob(f, c, r) * top;
	float tongue = blob(f, c + vec2(0.0, -r.y * 0.78), vec2(r.x * 0.55, r.y * 0.45)) * inside;
	vec3 col = mix(lip, vec3(0.42, 0.06, 0.12), inside);
	col = mix(col, vec3(1.0, 0.45, 0.5), tongue);
	return vec4(col, outer);
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
	if (face_style == 6 && p.z < 0.0) {
		// Drawn at 1.4x: a big face, filling the front of the ball.
		vec2 f = vec2(p.x, p.y) / 1.4;
		vec2 wide = clamp((1.0 - pupil_size) / 0.4, 0.0, 1.0);
		vec3 eye_emit = vec3(0.0);
		// Low on the face and set wide apart, as in a baby's face.
		vec4 l = grin_eye(f, vec2(-0.25, 0.04), eye_size.x, eye_height.x, pupil_size.x, pupil_offset.xy, 1.0, eye_emit);
		vec4 r = grin_eye(f, vec2(0.25, 0.04), eye_size.y, eye_height.y, pupil_size.y, pupil_offset.zw, -1.0, eye_emit);
		float cover = max(l.a, r.a) * (1.0 - happy);
		float blush = max(blob(f, vec2(-0.43, -0.13), vec2(0.1, 0.06)), blob(f, vec2(0.43, -0.13), vec2(0.1, 0.06))) * 0.45;
		col = mix(col, vec3(1.0, 0.45, 0.55), blush);
		col = mix(col, l.rgb * l.a + r.rgb * r.a, cover);
		emit = mix(emit, eye_emit, cover);
		float arcs = max(arc(f, vec2(-0.25, 0.04), 0.85), arc(f, vec2(0.25, 0.04), 0.85)) * happy;
		col = mix(col, vec3(0.12, 0.04, 0.1), arcs);
		vec4 m = grin_mouth(f, max(wide.x, wide.y) * (1.0 - happy), happy);
		col = mix(col, m.rgb, m.a);
		float dark = max(arcs, m.a);
		emit = mix(emit, vec3(0.0), dark * (1.0 - cover));
		paint = max(max(cover, dark), blush);
	} else if (face_style >= 4 && face_style <= 5) {
		// Bent going into the glass, so the eyes swim a little as it turns.
		vec3 bent = refract(into, p, 1.0 / 1.45);
		vec2 wide = clamp((1.0 - pupil_size) / 0.4, 0.0, 1.0);
		vec3 eye_emit = vec3(0.0);
		// Sunk well into the ball, so they swim behind the glass.
		vec4 l = glass_eye(p, bent, vec3(-0.28, 0.1, -0.45), 0.25 * eye_size.x, eye_height.x, wide.x,
			pupil_offset.xy, face_style == 4, eye_emit);
		vec4 r = glass_eye(p, bent, vec3(0.28, 0.1, -0.45), 0.25 * eye_size.y, eye_height.y, wide.y,
			pupil_offset.zw, face_style == 4, eye_emit);
		float cover = max(l.a, r.a) * (1.0 - happy);
		// Seen through a little of the glass's own colour.
		col = mix(col, mix(l.rgb * l.a + r.rgb * r.a, col, 0.1), cover);
		emit = mix(emit, eye_emit, cover);
		// Happy squeezes them shut into arcs, painted on the front.
		vec2 f = vec2(p.x, p.y);
		float arcs = p.z < 0.0 ? max(arc(f, vec2(-0.3, 0.12), 0.85), arc(f, vec2(0.3, 0.12), 0.85)) * happy : 0.0;
		col = mix(col, vec3(1.0, 0.6, 0.12), arcs);
		emit = mix(emit, vec3(1.0, 0.55, 0.1) * (0.5 + white_glow), arcs);
		// Still behind the glass: its highlight sits on top.
		col = mix(col, vec3(1.0), glint * 0.9);
		paint = arcs;
	} else if (p.z < 0.0 && face_style == 0) {
		vec2 f = vec2(p.x, p.y);
		vec3 eye_emit = vec3(0.0);
		vec4 l = eye(f, vec2(-EYE_CENTRE.x, EYE_CENTRE.y), eye_size.x, eye_height.x, pupil_size.x, pupil_offset.xy, eye_emit);
		vec4 r = eye(f, EYE_CENTRE, eye_size.y, eye_height.y, pupil_size.y, pupil_offset.zw, eye_emit);
		float cover = max(l.a, r.a) * (1.0 - happy);
		col = mix(col, l.rgb * l.a + r.rgb * r.a, cover);
		emit = mix(emit, eye_emit, cover);
		float arcs = max(arc(f, vec2(-EYE_CENTRE.x, EYE_CENTRE.y), 1.0), arc(f, EYE_CENTRE, 1.0)) * happy;
		col = mix(col, vec3(0.02), arcs);
		emit = mix(emit, vec3(0.0), arcs);
		paint = max(cover, arcs);
	} else if (p.z < 0.0) {
		vec2 f = vec2(p.x, p.y);
		// Where the eyes sit and how big, per style: wide apart and low.
		vec2 ec = face_style == 1 ? vec2(0.3, 0.02) : (face_style == 2 ? vec2(0.2, 0.05) : vec2(0.33, 0.06));
		vec2 er = face_style == 1 ? vec2(0.12, 0.17) : (face_style == 2 ? vec2(0.06, 0.07) : vec2(0.17, 0.22));
		float scale = face_style == 2 ? 0.8 : 1.0;
		vec2 wide = clamp((1.0 - pupil_size) / 0.4, 0.0, 1.0);
		vec3 eye_emit = vec3(0.0);
		vec4 l = bead(f, vec2(-ec.x, ec.y), er * eye_size.x, eye_height.x, pupil_offset.xy, wide.x, eye_emit);
		vec4 r = bead(f, ec, er * eye_size.y, eye_height.y, pupil_offset.zw, wide.y, eye_emit);
		float cover = max(l.a, r.a) * (1.0 - happy);
		// Blush under the outer corners of the eyes.
		float blush = max(patch(f, vec2(-ec.x - 0.14, ec.y - 0.2) * vec2(1.0, 1.0), vec2(0.12, 0.07)),
			patch(f, vec2(ec.x + 0.14, ec.y - 0.2), vec2(0.12, 0.07))) * 0.6;
		col = mix(col, vec3(1.0, 0.45, 0.55), blush);
		emit = mix(emit, vec3(1.0, 0.35, 0.45) * 0.25, blush);
		col = mix(col, l.rgb * l.a + r.rgb * r.a, cover);
		emit = mix(emit, eye_emit, cover);
		float arc_scale = er.x / 0.12 * 0.75;
		float arcs = max(arc(f, vec2(-ec.x, ec.y), arc_scale), arc(f, ec, arc_scale)) * happy;
		float m = mouth(f, max(wide.x, wide.y) * (1.0 - happy), scale);
		float dark = max(arcs, m);
		col = mix(col, vec3(0.12, 0.02, 0.05), dark);
		emit = mix(emit, vec3(0.0), dark);
		paint = max(max(cover, dark), blush);
	}

	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = mix(0.12, 0.8, paint);
	SPECULAR = mix(0.35, 0.1, paint);
}
