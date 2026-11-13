class_name CreatureEyes
extends Node3D
## A creature's eyes, which carry all its character: they blink, follow you,
## glint from hiding, go wide when found, squint cheekily as it runs, wink
## while it waits, and squeeze into happy arcs when caught.
##
## Each eye is a pivot (EyeL / EyeR) holding a white and a pupil. Scaling the
## pivot blinks, widens or squints the eye; moving the pupil across the
## white's front makes it look somewhere. The creature drives this from its
## physics tick (step()), since physics interpolation expects transforms to
## change only in ticks.

enum Mood { NORMAL, WIDE, SQUINT, HAPPY }

## How far the pupil sits from the eye's centre, and the widest angle it
## can turn from straight ahead before it would slide off the white.
const PUPIL_DISTANCE: float = 0.022
const MAX_LOOK_ANGLE: float = deg_to_rad(42.0)
## How quickly the pupils dart to a new target (per second).
const LOOK_RATE: float = 14.0
const BLINK_SECONDS: float = 0.14
const BLINK_GAP_MIN: float = 2.0
const BLINK_GAP_MAX: float = 5.0
const WINK_SECONDS: float = 0.35
## How each mood shapes the eye: the pivot's height, its overall size, and
## the pupil's size.
const MOOD_SHAPE := {
	Mood.NORMAL: [1.0, 1.0, 1.0],
	Mood.WIDE: [1.35, 1.25, 0.6],
	Mood.SQUINT: [0.4, 1.05, 1.0],
	Mood.HAPPY: [0.0, 1.0, 0.0],
}
## How quickly the eyes change shape between moods (per second).
const SHAPE_RATE: float = 18.0
## The whites glow faintly so they still read as white in the dim, warm
## room. The glint rises from there to its peak and settles back.
const WHITE_GLOW: float = 0.35
const GLINT_ENERGY: float = 3.0
const GLINT_SECONDS: float = 0.6
const ARC_DOTS: int = 7
const ARC_RADIUS: float = 0.022
const DOT_RADIUS: float = 0.0055

@onready var _eyes: Array[Node3D] = [$EyeL, $EyeR]
@onready var _pupils: Array[Node3D] = [$EyeL/Pupil, $EyeR/Pupil]

var mood: Mood = Mood.NORMAL
## Where the pupils want to point, in world space. A zero vector means
## straight ahead.
var look_target: Vector3 = Vector3.ZERO
var _look_dirs: Array[Vector3] = [Vector3.FORWARD, Vector3.FORWARD]
var _height: float = 1.0
var _size: float = 1.0
var _pupil_size: float = 1.0
var _blink_left: float = 0.0
var _next_blink: float = 0.0
var _wink_left: float = 0.0
var _wink_eye: int = 0
var _mood_left: float = 0.0
var _mood_after: Mood = Mood.NORMAL
var _after_seconds: float = 0.0
var _white_material: StandardMaterial3D
var _arcs: Array[Node3D] = []


func _ready() -> void:
	_next_blink = randf_range(BLINK_GAP_MIN, BLINK_GAP_MAX)
	# One material for both whites, this creature's own, so its glint
	# doesn't light up every creature's eyes.
	var white := $EyeL/White as MeshInstance3D
	_white_material = (white.material_override as StandardMaterial3D).duplicate()
	_white_material.emission_enabled = true
	_white_material.emission = Color.WHITE
	_white_material.emission_energy_multiplier = WHITE_GLOW
	for eye in _eyes:
		(eye.get_node("White") as MeshInstance3D).material_override = _white_material
		_add_catchlight(eye.get_node("Pupil") as Node3D)
		_arcs.append(_make_happy_arc(eye))


## Advances blinks, moods and where the pupils point. Called every physics tick.
func step(delta: float) -> void:
	if _mood_left > 0.0:
		_mood_left -= delta
		if _mood_left <= 0.0:
			mood = _mood_after
			_mood_left = _after_seconds
			_mood_after = Mood.NORMAL
			_after_seconds = 0.0
	_next_blink -= delta
	if _next_blink <= 0.0 and mood == Mood.NORMAL:
		_blink_left = BLINK_SECONDS
		_next_blink = randf_range(BLINK_GAP_MIN, BLINK_GAP_MAX)
	_blink_left = maxf(_blink_left - delta, 0.0)
	_wink_left = maxf(_wink_left - delta, 0.0)
	_update_shape(delta)
	_update_look(delta)


## Shows `new_mood` for `seconds`, then `after` for `after_seconds`, then
## back to normal. (After 0 seconds, `after` stays.)
func show_mood(new_mood: Mood, seconds: float, after: Mood = Mood.NORMAL, after_seconds: float = 0.0) -> void:
	mood = new_mood
	_mood_left = seconds
	_mood_after = after
	_after_seconds = after_seconds


func wink() -> void:
	if mood == Mood.NORMAL and _blink_left <= 0.0:
		_wink_left = WINK_SECONDS
		_wink_eye = randi() % 2


## A bright flash in the eyes, bright enough for the bloom to catch: two
## eyes shining out from under the bed.
func glint() -> void:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_white_material, "emission_energy_multiplier", GLINT_ENERGY, GLINT_SECONDS * 0.25)
	tween.tween_property(_white_material, "emission_energy_multiplier", WHITE_GLOW, GLINT_SECONDS * 0.75)


func is_glinting() -> bool:
	return _white_material.emission_energy_multiplier > WHITE_GLOW + 0.5


## How open an eye is right now (0 shut, 1 normal, more when wide).
func openness(eye: int) -> float:
	return _eyes[eye].scale.y / maxf(_size, 0.001)


## Where a pupil points, as an angle away from straight ahead (radians).
func look_angle(eye: int) -> float:
	return _look_dirs[eye].angle_to(Vector3.FORWARD)


func _update_shape(delta: float) -> void:
	var shape: Array = MOOD_SHAPE[mood]
	var blend: float = minf(SHAPE_RATE * delta, 1.0)
	_height = lerpf(_height, shape[0], blend)
	_size = lerpf(_size, shape[1], blend)
	_pupil_size = lerpf(_pupil_size, shape[2], blend)
	# A blink is a quick close and open: a dip shaped like half a sine wave.
	var blink: float = sin(_blink_left / BLINK_SECONDS * PI) if _blink_left > 0.0 else 0.0
	var wink: float = sin(_wink_left / WINK_SECONDS * PI) if _wink_left > 0.0 else 0.0
	for i in 2:
		var shut: float = maxf(blink, wink if i == _wink_eye else 0.0)
		var height: float = maxf(_height * (1.0 - shut * 0.92), 0.02)
		_eyes[i].scale = Vector3(_size, _size * height, _size)
		_pupils[i].scale = Vector3.ONE * _pupil_size
		_eyes[i].visible = mood != Mood.HAPPY or _height > 0.15
		_arcs[i].visible = mood == Mood.HAPPY


func _update_look(delta: float) -> void:
	for i in 2:
		var wanted: Vector3 = Vector3.FORWARD
		if look_target != Vector3.ZERO:
			# The target in this eye's own space; the face looks down -Z.
			var local: Vector3 = (_eyes[i].transform.origin.direction_to(to_local(look_target)))
			var angle: float = local.angle_to(Vector3.FORWARD)
			if angle > MAX_LOOK_ANGLE:
				# Turn only as far as the edge of the white, toward the target.
				var axis: Vector3 = Vector3.FORWARD.cross(local)
				wanted = Vector3.FORWARD.rotated(axis.normalized(), MAX_LOOK_ANGLE) \
					if axis.length() > 0.0001 else Vector3.FORWARD
			else:
				wanted = local
		# Blend and renormalise: close enough to a true rotation for small
		# steps, and safe when the two directions are nearly the same.
		_look_dirs[i] = _look_dirs[i].lerp(wanted, minf(LOOK_RATE * delta, 1.0)).normalized()
		_pupils[i].position = _look_dirs[i] * PUPIL_DISTANCE


## A tiny white dot on the pupil, a reflected light, which makes the eyes
## look wet and alive.
func _add_catchlight(pupil: Node3D) -> void:
	var dot := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.0045
	sphere.height = 0.009
	sphere.radial_segments = 8
	sphere.rings = 4
	dot.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE
	dot.material_override = material
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.position = Vector3(-0.005, 0.006, -0.012)
	pupil.add_child(dot)


## The "^" of a happy, squeezed-shut eye: a row of dark dots along an
## upward arc, shown in place of the eye.
func _make_happy_arc(eye: Node3D) -> Node3D:
	var arc := Node3D.new()
	arc.position = eye.position + Vector3(0.0, -0.006, -0.02)
	arc.visible = false
	var sphere := SphereMesh.new()
	sphere.radius = DOT_RADIUS
	sphere.height = DOT_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.02, 0.02)
	for k in ARC_DOTS:
		var angle: float = lerpf(deg_to_rad(20.0), deg_to_rad(160.0), float(k) / (ARC_DOTS - 1))
		var dot := MeshInstance3D.new()
		dot.mesh = sphere
		dot.material_override = material
		dot.position = Vector3(cos(angle) * ARC_RADIUS, sin(angle) * ARC_RADIUS * 0.8, 0.0)
		arc.add_child(dot)
	add_child(arc)
	return arc
