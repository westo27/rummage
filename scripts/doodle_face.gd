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
## startled mouth. A fifth, when there is one, is a right eye of its own (for
## lopsided faces); otherwise the right eye is the eye mirrored. A sixth is
## extras that stay still whatever the mood (brows, tears, hearts).
enum Cell { EYE, HAPPY_EYE, MOUTH, STARTLED_MOUTH, RIGHT_EYE, EXTRAS }
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
## The same for the right eye, when the face has one of its own.
var right_span: Vector3 = DEFAULT_SPAN
## Where each drawn part goes: see LAYOUT.
var layout: Dictionary = LAYOUT

const DEFAULT_SPAN := Vector3(0.15, 0.85, 0.5)
## How much wider a made happy eye is than the eye it comes from.
const HAPPY_GROW: float = 1.7
## The game draws the happy eye in a box this much bigger than the eye's
## (creature_marble.gdshader's HAPPY_BOX), so a big arch fits: a made one is
## drawn this much smaller in its cell, at the eye's pen weight once scaled.
const HAPPY_BOX: float = 1.6
## Where a drawn face's parts go, as seen from the front (x to your right, y
## up, in units of the face): each box's middle and half its size. These are
## the painter's; a face from a sheet has its own, saved beside it as
## <name>.json.
const LAYOUT := {
	"eye": Vector3(-0.3, 0.08, 0.28),
	"eye2": Vector3(0.3, 0.08, 0.28),
	"mouth": Vector3(0.0, -0.22, 0.3),
	"extra": Vector3(0.0, 0.0, 0.5),
}

static var _drawn_faces: Array[Texture2D] = []
static var _drawn_spans: Array[Vector3] = []
static var _drawn_right_spans: Array[Vector3] = []
static var _drawn_layouts: Array[Dictionary] = []
static var _drawn_loaded: bool = false
## When set (before the first face is picked), only these drawn faces are
## used: the press images use PRESS_FACES.
static var only: Array[String] = []

## The faces the press images use.
const PRESS_FACES: Array[String] = ["doodle_01", "doodle_06", "doodle_07", "doodle_08",
	"doodle_26", "doodle_34"]


static func random() -> DoodleFace:
	var faces: Array[Texture2D] = drawn_faces()
	if not faces.is_empty():
		var face := DoodleFace.new()
		var pick: int = randi() % faces.size()
		face.drawn = faces[pick]
		face.eye_span = _drawn_spans[pick]
		face.right_span = _drawn_right_spans[pick]
		face.layout = _drawn_layouts[pick]
		return face
	return variant(IN_PLAY.pick_random())


## Every face in FOLDER, loaded once.
static func drawn_faces() -> Array[Texture2D]:
	if not _drawn_loaded:
		_drawn_loaded = true
		for name: String in face_names():
			if not only.is_empty() and not name in only:
				continue
			var tex: Texture2D = load_drawn(name)
			_drawn_faces.append(tex)
			_drawn_spans.append(measure_eye(tex.get_image()))
			_drawn_right_spans.append(measure_eye(tex.get_image(), Cell.RIGHT_EYE))
			_drawn_layouts.append(load_layout(name))
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


## A drawn face's layout: from <name>.json beside it, else the painter's.
static func load_layout(name: String) -> Dictionary:
	var path: String = "%s/%s.json" % [FOLDER, name]
	if not FileAccess.file_exists(path):
		return LAYOUT
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return LAYOUT
	var out: Dictionary = LAYOUT.duplicate()
	for key: String in LAYOUT:
		var v: Variant = (data as Dictionary).get(key)
		if v is Array and (v as Array).size() == 3:
			out[key] = Vector3(v[0], v[1], v[2])
	return out


## Saves a layout beside a face (or removes it, for the painter's).
static func save_layout(name: String, face_layout: Dictionary) -> void:
	var path: String = "%s/%s.json" % [FOLDER, name]
	if face_layout == LAYOUT:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var data := {}
	for key: String in face_layout:
		var v: Vector3 = face_layout[key]
		data[key] = [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))


static func apply_layout(mat: ShaderMaterial, face_layout: Dictionary) -> void:
	mat.set_shader_parameter("face_box_eye", face_layout["eye"])
	mat.set_shader_parameter("face_box_eye2", face_layout["eye2"])
	mat.set_shader_parameter("face_box_mouth", face_layout["mouth"])
	mat.set_shader_parameter("face_box_extra", face_layout.get("extra", LAYOUT["extra"]))


## Where the ink of a drawn face's eye sits in its square: see eye_span.
static func measure_eye(atlas: Image, which: int = Cell.EYE) -> Vector3:
	var cell: int = atlas.get_height()
	if (which + 1) * cell > atlas.get_width():
		return DEFAULT_SPAN
	var eye := atlas.get_region(Rect2i(which * cell, 0, cell, cell))
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
	mat.set_shader_parameter("face_right_span", right_span)
	mat.set_shader_parameter("face_cells", cells())
	apply_layout(mat, layout)
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


## How many cells this drawn face has (4, or 5 with its own right eye).
func cells() -> int:
	return CELLS if drawn == null else roundi(float(drawn.get_width()) / drawn.get_height())


## The hand-drawn face: its eyes and mouth cells, at the shader's positions.
func _draw_drawn(canvas: CanvasItem, radius: float) -> void:
	var cell: float = drawn.get_height()
	var own_right: bool = cells() > CELLS
	# Face units to the ball's radius: the shader draws the face 1.45x.
	var to_ball: float = 1.45 * radius
	# The right eye is the eye mirrored (x flipped about its middle), unless
	# the face has one of its own.
	var parts: Array = [
		["eye", Cell.EYE, false],
		["eye2", Cell.RIGHT_EYE if own_right else Cell.EYE, not own_right],
		["mouth", Cell.MOUTH, false],
	]
	if cells() > Cell.EXTRAS:
		parts.append(["extra", Cell.EXTRAS, false])
	for part: Array in parts:
		var box: Vector3 = layout.get(part[0], LAYOUT[part[0]])
		var at := Vector2(box.x, -box.y) * to_ball
		var size: float = box.z * to_ball
		canvas.draw_set_transform(at, 0.0, Vector2(-1.0 if part[2] else 1.0, 1.0))
		canvas.draw_texture_rect_region(drawn, Rect2(-size, -size, size * 2.0, size * 2.0),
			Rect2(int(part[1]) * cell, 0.0, cell, cell))
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
## the eye's own pen weight, HAPPY_GROW times as wide as the eye (within its
## box), so it reads.
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
	# Smooth out the steps, then scale up about the eye's middle: a happy eye
	# is a big, clear arch, wider than the eye and filling most of its box.
	tops = _smooth(tops, 3)
	var middle := Vector2(used.get_center())
	var width: float = clampf(maxf(used.size.x * HAPPY_GROW, size * 0.75), 1.0, size * 1.3)
	var grow: float = maxf(width / maxf(used.size.x, 1.0), 1.0)
	var lift: float = (used.size.y * 0.5 - weight) * 0.5
	for i in tops.size():
		# A flat-topped eye still needs to read as a curve: bow it a little.
		var t: float = float(i) / (tops.size() - 1) * 2.0 - 1.0
		var p: Vector2 = tops[i] + Vector2(0.0, lift + t * t * size * 0.04)
		tops[i] = middle + (p - middle) * grow
		# Into the bigger happy box: about the cell's middle, HAPPY_BOX smaller.
		var c := Vector2(size, size) * 0.5
		tops[i] = c + (tops[i] - c) / HAPPY_BOX
	draw_stroke(out, tops, weight * 0.5 / HAPPY_BOX)
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
