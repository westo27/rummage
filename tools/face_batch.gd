extends Node
## Draws a batch of simple line-doodle faces through the face painter's own
## pen and saves them to res://faces, as if drawn by hand: every stroke gets
## a small, smooth wobble. Faces already in the folder are left alone.
## Run: Godot --path . --resolution 1400x800 res://tools/face_batch.tscn

const C := Vector2(256, 256)
## The pen for lines, in canvas pixels.
const LINE: float = 14.0
## Each part is drawn about the middle of its square and scaled up by this,
## so the faces read at marble size: eyes, happy eyes, mouths.
const PART_SCALE: Array[float] = [1.3, 1.3, 1.7, 1.7]

var _painter: Control
var _wobble_seed: float = 0.0
var _scale: float = 1.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_painter = (load("res://tools/face_painter.tscn") as PackedScene).instantiate()
	add_child(_painter)
	await get_tree().process_frame
	var existing: Array[String] = DoodleFace.face_names()
	var faces: Dictionary = {
		"dot_smile": [_dot_eye, _caret, _smile, _o],
		"tongue": [_dot_eye, _caret, _tongue, _o],
		"toothy": [_dot_eye, _caret, _teeth, _square_mouth],
		"kitty": [_dot_eye, _caret, _cat_mouth, _o],
		"big_grin": [_dot_eye, _caret, _grin, _big_o],
		"sweetheart": [_heart_cheek_eye, _caret, _smile, _o],
		"kissy": [_dot_eye, _caret, _kiss, _o],
		"chuffed": [_dot_eye, _caret, _open_d, _big_o],
		"snoozy": [_closed_eye, _caret, _small_smile, _o],
		"piggy": [_dot_eye, _caret, _snout, _big_o],
		"cheeky": [_brow_eye, _caret, _smirk, _o],
		"squeezy": [_squeeze_eye, _squeeze_eye, _open_triangle, _big_o],
		"wobbly": [_dot_eye, _caret, _zigzag, _big_o],
		"gappy": [_dot_eye, _caret, _gap_tooth, _big_o],
	}
	for face_name: String in faces:
		if face_name in existing:
			continue
		_painter.call("_new_face")
		var parts: Array = faces[face_name]
		for part in parts.size():
			_painter.call("_select_part", part)
			_wobble_seed = randf() * 100.0
			_scale = PART_SCALE[part]
			(parts[part] as Callable).call()
			_painter.call("_show_part")
		(_painter.get("_name_edit") as LineEdit).text = face_name
		_painter.call("_save")
		print("drew %s" % face_name)
	print("RESULT face batch done")
	get_tree().quit()


# --- Pen ---------------------------------------------------------------------

## One stroke through the points, with a hand's wobble.
func _stroke(points: PackedVector2Array, pen: float = LINE) -> void:
	_painter.set("_brush", pen)
	_painter.call("_begin_stroke", false)
	var dense := PackedVector2Array()
	for i in points.size() - 1:
		for k in 8:
			dense.append(_scaled(points[i].lerp(points[i + 1], k / 8.0)))
	dense.append(_scaled(points[points.size() - 1]))
	var last := _shake(dense[0], 0)
	for i in range(1, dense.size()):
		var at := _shake(dense[i], i)
		_painter.call("_stamp_line", last, at)
		last = at


func _scaled(p: Vector2) -> Vector2:
	return C + (p - C) * _scale


func _shake(p: Vector2, i: int) -> Vector2:
	var t: float = i * 0.12 + _wobble_seed
	return p + Vector2(sin(t * 1.7) + sin(t * 3.1) * 0.5, cos(t * 1.3) + sin(t * 2.3) * 0.5) * 2.2


func _arc(centre: Vector2, radius: Vector2, from: float, to: float, steps: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a: float = lerpf(from, to, float(i) / steps)
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	return pts


## An inked-in dot: a fat pen dabbed in a short line.
func _dot(at: Vector2, size: Vector2) -> void:
	_stroke(PackedVector2Array([at - Vector2(0, size.y - size.x), at + Vector2(0, size.y - size.x)]), size.x * _scale)


# --- Eyes (drawn as the left eye; the right is this mirrored) -----------------

func _dot_eye() -> void:
	_dot(C, Vector2(30, 40))


func _heart_cheek_eye() -> void:
	_dot(C + Vector2(10, 0), Vector2(30, 40))
	# A little heart low on the outer side: the cheek.
	var h := C + Vector2(-110, 95)
	_stroke(PackedVector2Array([h + Vector2(0, 28), h + Vector2(-30, 0), h + Vector2(-26, -20),
		h + Vector2(-12, -24), h + Vector2(0, -10), h + Vector2(12, -24), h + Vector2(26, -20),
		h + Vector2(30, 0), h + Vector2(0, 28)]), 8.0)


func _closed_eye() -> void:
	_stroke(_arc(C + Vector2(0, -20), Vector2(60, 45), 0.25, PI - 0.25))


func _brow_eye() -> void:
	_dot(C + Vector2(0, 20), Vector2(28, 36))
	# A brow lifted at the inner end: a cheeky look.
	_stroke(PackedVector2Array([C + Vector2(-60, -55), C + Vector2(55, -80)]))


func _squeeze_eye() -> void:
	# ">" : with the mirror, the face reads > <.
	_stroke(PackedVector2Array([C + Vector2(-45, -45), C + Vector2(40, 0), C + Vector2(-45, 45)]))


func _caret() -> void:
	_stroke(PackedVector2Array([C + Vector2(-55, 30), C + Vector2(0, -30), C + Vector2(55, 30)]))


# --- Mouths -------------------------------------------------------------------

func _smile() -> void:
	_stroke(_arc(C + Vector2(0, -40), Vector2(80, 70), 0.55, PI - 0.55))


func _small_smile() -> void:
	_stroke(_arc(C + Vector2(0, -20), Vector2(50, 40), 0.6, PI - 0.6))


func _smirk() -> void:
	_stroke(_arc(C + Vector2(20, -60), Vector2(80, 80), 0.6, PI - 1.1))


func _o() -> void:
	_stroke(_arc(C, Vector2(26, 32), 0.0, TAU + 0.3))


func _big_o() -> void:
	_stroke(_arc(C, Vector2(55, 66), 0.0, TAU + 0.3))


func _tongue() -> void:
	_smile()
	_stroke(_arc(C + Vector2(25, 20), Vector2(28, 38), -0.2, PI + 0.2))


func _teeth() -> void:
	_stroke(PackedVector2Array([C + Vector2(-90, 0), C + Vector2(90, 0)]))
	for x: float in [-45.0, 15.0]:
		_stroke(PackedVector2Array([C + Vector2(x, 0), C + Vector2(x, 40), C + Vector2(x + 30, 40), C + Vector2(x + 30, 0)]), 9.0)


func _square_mouth() -> void:
	_stroke(PackedVector2Array([C + Vector2(-40, -35), C + Vector2(40, -35), C + Vector2(48, 35),
		C + Vector2(-48, 35), C + Vector2(-40, -35), C + Vector2(-20, -35)]))


func _cat_mouth() -> void:
	_stroke(_arc(C + Vector2(-35, -10), Vector2(35, 35), 0.1, PI - 0.1))
	_stroke(_arc(C + Vector2(35, -10), Vector2(35, 35), 0.1, PI - 0.1))


func _grin() -> void:
	var top := _arc(C + Vector2(0, -150), Vector2(150, 150), 1.05, PI - 1.05)
	var bottom := _arc(C + Vector2(0, -80), Vector2(120, 140), 0.85, PI - 0.85)
	_stroke(top)
	_stroke(bottom)
	_stroke(PackedVector2Array([C + Vector2(-95, 12), C + Vector2(95, 12)]), 7.0)
	for x: float in [-50.0, 0.0, 50.0]:
		_stroke(PackedVector2Array([C + Vector2(x, -8), C + Vector2(x, 50)]), 7.0)


func _kiss() -> void:
	_stroke(_arc(C + Vector2(-10, -28), Vector2(30, 26), -PI * 0.55, PI * 0.5))
	_stroke(_arc(C + Vector2(-10, 26), Vector2(30, 26), -PI * 0.5, PI * 0.55))


func _open_d() -> void:
	_stroke(PackedVector2Array([C + Vector2(-80, -25), C + Vector2(80, -25)]))
	_stroke(_arc(C + Vector2(0, -25), Vector2(80, 75), 0.0, PI))


func _snout() -> void:
	_stroke(_arc(C, Vector2(70, 48), 0.0, TAU + 0.3))
	_dot(C + Vector2(-24, 0), Vector2(13, 17))
	_dot(C + Vector2(24, 0), Vector2(13, 17))


func _open_triangle() -> void:
	_stroke(PackedVector2Array([C + Vector2(-30, -35), C + Vector2(30, -35), C + Vector2(50, 40),
		C + Vector2(-50, 40), C + Vector2(-30, -35)]))


func _zigzag() -> void:
	var pts := PackedVector2Array()
	for i in 7:
		pts.append(C + Vector2(-90 + i * 30, -12 if i % 2 == 0 else 12))
	_stroke(pts)


func _gap_tooth() -> void:
	_smile()
	_stroke(PackedVector2Array([C + Vector2(-14, 28), C + Vector2(-14, 62), C + Vector2(14, 62), C + Vector2(14, 28)]), 8.0)
