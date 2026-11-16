class_name DoodleFace
extends RefCounted
## The face a child drew on a marble in felt-tip: which eyes, which mouth,
## and how lopsided. Picked once per creature and shared with the ball that
## drops into the HUD bag, so the caught marble wears the same face.
## The creature's shader (creature_marble.gdshader) draws it in 3D; draw()
## here is the bag's small 2D version.
## Faces drawn by hand in the face painter (tools/face_painter.tscn) live in
## FOLDER; when there are any, creatures wear those instead of the built-in
## doodles below.

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

static var _drawn_faces: Array[Texture2D] = []
static var _drawn_loaded: bool = false


static func random() -> DoodleFace:
	var faces: Array[Texture2D] = drawn_faces()
	if not faces.is_empty():
		var face := DoodleFace.new()
		face.drawn = faces.pick_random()
		face.lop = randf_range(-1.0, 1.0)
		return face
	return variant(IN_PLAY.pick_random())


## Every face in FOLDER, loaded once.
static func drawn_faces() -> Array[Texture2D]:
	if not _drawn_loaded:
		_drawn_loaded = true
		for name: String in face_names():
			_drawn_faces.append(load_drawn(name))
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
	return texture_from(image)


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
