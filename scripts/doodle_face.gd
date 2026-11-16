class_name DoodleFace
extends RefCounted
## The face a child drew on a marble in felt-tip: which eyes, which mouth,
## and how lopsided. Picked once per creature and shared with the ball that
## drops into the HUD bag, so the caught marble wears the same face.
## The creature's shader (creature_marble.gdshader) draws it in 3D; draw()
## here is the bag's small 2D version.
## Faces drawn by hand in the face painter (tools/face_painter.tscn) live in
## FOLDER; when there are any, creatures wear those instead of the built-in
## doodles below. A face with no happy eye or startled mouth drawn gets them
## made from its eye and mouth (fill_missing).

const FOLDER: String = "res://faces"
## A drawn face is four square cells side by side: eye, happy eye, mouth,
## startled mouth.
enum Cell { EYE, HAPPY_EYE, MOUTH, STARTLED_MOUTH }
const CELLS: int = 4

enum Eyes { DOTS, RINGS, LASHES, BEANS, GOOGLY, SLEEPY, STARS, HEARTS, SPIRAL, WINK }
enum Mouth { SMILE, GRIN, WONKY, CAT, TONGUE, BUCK, ZIGZAG, KISS, TOOTHY }
## Extra bits, as flags.
const BROWS: int = 1
const NOSE: int = 2
const FRECKLES: int = 4
const TASH: int = 8
const GLASSES: int = 16
const TUFT: int = 32

## The named faces: [name, eyes, mouth, extras].
const VARIANTS: Array = [
	["Classic", Eyes.DOTS, Mouth.SMILE, 0],
	["Ringo", Eyes.RINGS, Mouth.GRIN, 0],
	["Lashes", Eyes.LASHES, Mouth.SMILE, 0],
	["Bean", Eyes.BEANS, Mouth.CAT, 0],
	["Googly", Eyes.GOOGLY, Mouth.WONKY, 0],
	["Dozy", Eyes.SLEEPY, Mouth.SMILE, 0],
	["Starry", Eyes.STARS, Mouth.GRIN, 0],
	["Lovey", Eyes.HEARTS, Mouth.SMILE, 0],
	["Cheeky", Eyes.DOTS, Mouth.TONGUE, 0],
	["Bucky", Eyes.RINGS, Mouth.BUCK, NOSE],
	["Swot", Eyes.DOTS, Mouth.SMILE, GLASSES | NOSE],
	["Worrier", Eyes.GOOGLY, Mouth.ZIGZAG, BROWS],
	["Freckles", Eyes.RINGS, Mouth.GRIN, FRECKLES],
	["Tash", Eyes.DOTS, Mouth.SMILE, TASH | NOSE],
	["Kissy", Eyes.LASHES, Mouth.KISS, 0],
	["Toothy", Eyes.BEANS, Mouth.TOOTHY, BROWS],
	["Dizzy", Eyes.SPIRAL, Mouth.WONKY, 0],
	["Tufty", Eyes.DOTS, Mouth.CAT, TUFT],
	["Winky", Eyes.WINK, Mouth.TONGUE, 0],
	["Posh", Eyes.LASHES, Mouth.SMILE, BROWS | NOSE],
]
## Which of VARIANTS creatures pick from.
const IN_PLAY: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]

const INK := Color(0.03, 0.02, 0.09)
const CHEEK := Color(1.0, 0.42, 0.55, 0.6)

var eyes: Eyes = Eyes.DOTS
var mouth: Mouth = Mouth.SMILE
var extras: int = 0
## -1..1: one eye a touch bigger and higher than the other.
var lop: float = 0.0
## A face drawn in the face painter, or null for a built-in doodle.
var drawn: Texture2D = null
## Where the drawn eye sits in its square (0..1): left edge, right edge,
## middle height. A blink is a line across exactly that.
var eye_span: Vector3 = DEFAULT_SPAN

const DEFAULT_SPAN := Vector3(0.15, 0.85, 0.5)

static var _drawn_faces: Array[Texture2D] = []
static var _drawn_spans: Array[Vector3] = []
static var _drawn_loaded: bool = false


static func random() -> DoodleFace:
	var faces: Array[Texture2D] = drawn_faces()
	if not faces.is_empty():
		var face := DoodleFace.new()
		var pick: int = randi() % faces.size()
		face.drawn = faces[pick]
		face.eye_span = _drawn_spans[pick]
		face.lop = randf_range(-1.0, 1.0)
		return face
	return variant(IN_PLAY.pick_random())


## Every face in FOLDER, loaded once.
static func drawn_faces() -> Array[Texture2D]:
	if not _drawn_loaded:
		_drawn_loaded = true
		for name: String in face_names():
			var tex: Texture2D = load_drawn(name)
			_drawn_faces.append(tex)
			_drawn_spans.append(measure_eye(tex.get_image()))
	return _drawn_faces


## The names of the faces in FOLDER (file names without ".png").
static func face_names() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return names
	for file: String in dir.get_files():
		# In an exported game the PNGs are listed by their import files.
		file = file.trim_suffix(".import").trim_suffix(".remap")
		if file.ends_with(".png") and not file.get_basename() in names:
			names.append(file.get_basename())
	names.sort()
	return names


## A drawn face's texture, with mipmaps so it stays smooth at a distance.
static func load_drawn(name: String) -> Texture2D:
	var path: String = "%s/%s.png" % [FOLDER, name]
	var image: Image
	if ResourceLoader.exists(path):
		image = (load(path) as Texture2D).get_image()
	else:
		image = Image.load_from_file(ProjectSettings.globalize_path(path))
	return texture_from(fill_missing(image))


## Where the ink of a drawn face's eye sits in its square: see eye_span.
static func measure_eye(atlas: Image) -> Vector3:
	var cell: int = atlas.get_height()
	var eye := atlas.get_region(Rect2i(0, 0, cell, cell))
	if eye.is_compressed():
		eye.decompress()
	var used: Rect2i = eye.get_used_rect()
	if used.size.x <= 0:
		return DEFAULT_SPAN
	return Vector3(float(used.position.x) / cell, float(used.end.x) / cell,
		(used.position.y + used.size.y * 0.5) / cell)


## The face painter's live texture uses this too.
static func texture_from(image: Image) -> ImageTexture:
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## One of VARIANTS, drawn a little lopsided at random.
static func variant(index: int) -> DoodleFace:
	var face := DoodleFace.new()
	var v: Array = VARIANTS[index]
	face.eyes = v[1]
	face.mouth = v[2]
	face.extras = v[3]
	face.lop = randf_range(-1.0, 1.0)
	return face


func apply(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("face_eyes", eyes)
	mat.set_shader_parameter("face_mouth", mouth)
	mat.set_shader_parameter("face_extras", extras)
	mat.set_shader_parameter("face_lop", lop)
	mat.set_shader_parameter("face_drawn", drawn != null)
	mat.set_shader_parameter("face_eye_span", eye_span)
	mat.set_shader_parameter("face_tex", drawn)


## Draws the face on `canvas` for a ball of `radius`, centred on its origin,
## facing the viewer (y down). Positions match the shader's head-on face.
func draw(canvas: CanvasItem, radius: float) -> void:
	if drawn != null:
		_draw_drawn(canvas, radius)
		return
	var w: float = maxf(radius * 0.085, 1.0)
	var tilt: float = lop * 0.125
	for side: float in [-1.0, 1.0]:
		var at := Vector2(0.36 * side, -0.09 + tilt * 0.14 * side) * radius
		var r: float = radius * 0.16 * (1.0 - tilt * side)
		canvas.draw_circle(Vector2(0.6 * side, 0.17) * radius, radius * 0.12, CHEEK)
		match eyes:
			Eyes.DOTS:
				canvas.draw_circle(at, r * 0.65, INK)
			_:
				canvas.draw_arc(at, r, 0.0, TAU, 16, INK, w, true)
				canvas.draw_circle(at + Vector2(0.0, r * 0.1), r * 0.5, INK)
				if eyes == Eyes.LASHES:
					for i in 3:
						var a: float = -PI * 0.5 + (float(i) - 1.0) * 0.42 - 0.3 * side
						var dir := Vector2(cos(a), sin(a))
						canvas.draw_line(at + dir * r, at + dir * r * 1.55, INK, w * 0.8, true)
	var m := Vector2(0.0, 0.25) * radius
	var mr: float = radius * 0.15
	match mouth:
		Mouth.GRIN:
			canvas.draw_line(m - Vector2(mr * 1.15, 0.0), m + Vector2(mr * 1.15, 0.0), INK, w, true)
			canvas.draw_arc(m, mr * 1.15, 0.0, PI, 12, INK, w, true)
		Mouth.WONKY:
			canvas.draw_arc(m - Vector2(0.0, mr * 1.6), mr * 2.0, PI * 0.37, PI * 0.63, 10, INK, w, true)
		_:
			canvas.draw_arc(m - Vector2(0.0, mr * 0.6), mr, PI * 0.18, PI * 0.82, 10, INK, w, true)


## The hand-drawn face: its eye (mirrored for the right) and mouth cells, at
## the shader's positions.
func _draw_drawn(canvas: CanvasItem, radius: float) -> void:
	var cell: float = drawn.get_height()
	var eye_box: float = 0.41 * radius
	for side: float in [-1.0, 1.0]:
		var tilt: float = lop * 0.2 * side
		var at := Vector2(0.435 * side, -0.116 + tilt * 0.14) * radius
		var box: float = eye_box * (1.0 - tilt)
		# Mirroring the right eye: draw it with x flipped about its centre.
		canvas.draw_set_transform(at, 0.0, Vector2(-1.0 if side > 0.0 else 1.0, 1.0))
		canvas.draw_texture_rect_region(drawn, Rect2(-box, -box, box * 2.0, box * 2.0),
			Rect2(Cell.EYE * cell, 0.0, cell, cell))
	var mouth_box: float = 0.435 * radius
	canvas.draw_set_transform(Vector2(0.0, 0.32 * radius), 0.0, Vector2.ONE)
	canvas.draw_texture_rect_region(drawn, Rect2(-mouth_box, -mouth_box, mouth_box * 2.0, mouth_box * 2.0),
		Rect2(Cell.MOUTH * cell, 0.0, cell, cell))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Making the happy eye and startled mouth -----------------------------------

## Fills in a drawn face's happy eye and startled mouth when they're blank,
## from its eye and mouth. Returns a new atlas; drawn parts are kept as they are.
static func fill_missing(atlas: Image) -> Image:
	atlas = _rgba(atlas)
	var cell: int = atlas.get_height()
	for pair: Array in [[Cell.HAPPY_EYE, Cell.EYE], [Cell.STARTLED_MOUTH, Cell.MOUTH]]:
		var target: int = pair[0]
		if atlas.get_region(Rect2i(target * cell, 0, cell, cell)).get_used_rect().size.x > 0:
			continue
		var source := atlas.get_region(Rect2i(int(pair[1]) * cell, 0, cell, cell))
		var made: Image = happy_from_eye(source) if target == Cell.HAPPY_EYE else startled_from_mouth(source)
		atlas.blit_rect(made, Rect2i(0, 0, cell, cell), Vector2i(target * cell, 0))
	return atlas


## The happy eye: the top edge of the eye, traced as a closed "^" arch, in
## the eye's own pen weight. Small eyes get a bigger arch, so it reads.
static func happy_from_eye(eye: Image) -> Image:
	eye = _rgba(eye)
	var size: int = eye.get_width()
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var used: Rect2i = eye.get_used_rect()
	if used.size.x <= 0:
		return out
	# The topmost ink in each column, sampled every few pixels.
	var step: int = maxi(size / 128, 1)
	var tops := PackedVector2Array()
	for x in range(used.position.x, used.end.x, step):
		for y in range(used.position.y, used.end.y, step):
			if eye.get_pixel(x, y).a > 0.5:
				tops.append(Vector2(x, y))
				break
	if tops.size() < 2:
		return out
	var weight: float = pen_weight(eye)
	# Trace along the outside of the line: shift down by half the pen.
	for i in tops.size():
		tops[i].y += weight * 0.5
	# Smooth out the steps, then scale up about the eye's middle if it's small.
	tops = _smooth(tops, 3)
	var middle := Vector2(used.get_center())
	var min_width: float = size * 0.3
	var grow: float = maxf(min_width / maxf(used.size.x, 1.0), 1.0)
	var lift: float = (used.size.y * 0.5 - weight) * 0.5
	for i in tops.size():
		# A flat-topped eye still needs to read as a curve: bow it a little.
		var t: float = float(i) / (tops.size() - 1) * 2.0 - 1.0
		var p: Vector2 = tops[i] + Vector2(0.0, lift + t * t * size * 0.04)
		tops[i] = middle + (p - middle) * grow
	draw_stroke(out, tops, weight * 0.5)
	return out


## The startled mouth: a little "o" in the mouth's pen weight, sized to the
## mouth and centred where it sits.
static func startled_from_mouth(mouth: Image) -> Image:
	mouth = _rgba(mouth)
	var size: int = mouth.get_width()
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var used: Rect2i = mouth.get_used_rect()
	var centre: Vector2 = Vector2(size, size) * 0.5
	var width: float = size * 0.25
	var weight: float = size * 0.03
	if used.size.x > 0:
		centre = Vector2(used.get_center())
		width = clampf(used.size.x * 0.45, size * 0.12, size * 0.3)
		weight = pen_weight(mouth)
	var ring := PackedVector2Array()
	for i in 41:
		var a: float = TAU * i / 40.0 + 0.3
		ring.append(centre + Vector2(cos(a) * width * 0.5, sin(a) * width * 0.62))
	draw_stroke(out, ring, weight * 0.5)
	return out


## How thick the drawing's lines are, in pixels: the commonest length of a
## run of ink across a row or down a column (whichever is shorter).
static func pen_weight(image: Image) -> float:
	var size: int = image.get_width()
	var used: Rect2i = image.get_used_rect()
	var runs: Array[int] = []
	for horizontal: bool in [true, false]:
		var lines: int = used.size.y if horizontal else used.size.x
		for i in range(0, lines, maxi(lines / 24, 1)):
			var run: int = 0
			var length: int = used.size.x if horizontal else used.size.y
			for j in length:
				var x: int = used.position.x + j if horizontal else used.position.x + i
				var y: int = used.position.y + i if horizontal else used.position.y + j
				if image.get_pixel(x, y).a > 0.5:
					run += 1
				elif run > 0:
					runs.append(run)
					run = 0
			if run > 0:
				runs.append(run)
	if runs.is_empty():
		return size * 0.03
	runs.sort()
	# The lower quarter: lines crossed square on, not along their length.
	return clampf(runs[runs.size() / 4], size * 0.02, size * 0.08)


## Ink along a path, round-ended, with a soft edge.
static func draw_stroke(image: Image, points: PackedVector2Array, radius: float) -> void:
	var size: int = image.get_width()
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var lo := Vector2i(floori(minf(a.x, b.x) - radius - 2.0), floori(minf(a.y, b.y) - radius - 2.0))
		var hi := Vector2i(ceili(maxf(a.x, b.x) + radius + 2.0), ceili(maxf(a.y, b.y) + radius + 2.0))
		for y in range(maxi(lo.y, 0), mini(hi.y, size)):
			for x in range(maxi(lo.x, 0), mini(hi.x, size)):
				var p := Vector2(x + 0.5, y + 0.5)
				var ab: Vector2 = b - a
				var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				var cover: float = clampf((radius + 0.75 - p.distance_to(a + ab * t)) / 1.5, 0.0, 1.0)
				if cover > image.get_pixel(x, y).a:
					image.set_pixel(x, y, Color(INK.r, INK.g, INK.b, cover))


static func _smooth(points: PackedVector2Array, reach: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size():
		var sum := Vector2.ZERO
		var count: int = 0
		for k in range(maxi(i - reach, 0), mini(i + reach + 1, points.size())):
			sum += points[k]
			count += 1
		out.append(sum / count)
	return out


static func _rgba(image: Image) -> Image:
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image
