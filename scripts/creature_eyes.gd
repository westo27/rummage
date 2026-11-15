class_name CreatureEyes
extends Node3D
## A creature's eyes, which carry all its character: they blink, follow you,
## glint from hiding, go wide when found, squint cheekily as it runs, wink
## while it waits, and squeeze into happy arcs when caught.
##
## The eyes are painted flat on the ball by the body's shader
## (shaders/creature_marble.gdshader). This works out their shape and where
## they look and hands that to the shader each tick. EyeL / EyeR are empty
## pivots marking where each eye sits, used to aim the look; their scale
## holds each eye's shape. The creature drives this from its physics tick
## (step()).

enum Mood { NORMAL, WIDE, SQUINT, HAPPY }

## The widest angle a pupil can turn from straight ahead; at this angle it
## reaches the edge of the white.
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

@onready var _eyes: Array[Node3D] = [$EyeL, $EyeR]
## The ball whose shader draws the eyes. Its material is looked up each
## tick, since the creature gives it its own copy after this node is ready.
@onready var _body: MeshInstance3D = $"../Body"

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
var _white_glow: float = WHITE_GLOW


func _ready() -> void:
	_next_blink = randf_range(BLINK_GAP_MIN, BLINK_GAP_MAX)


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
	_send_to_shader()


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
	tween.tween_property(self, "_white_glow", GLINT_ENERGY, GLINT_SECONDS * 0.25)
	tween.tween_property(self, "_white_glow", WHITE_GLOW, GLINT_SECONDS * 0.75)


func is_glinting() -> bool:
	return _white_glow > WHITE_GLOW + 0.5


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


## Hands this tick's eyes to the body's shader.
func _send_to_shader() -> void:
	var mat := _body.material_override as ShaderMaterial
	if mat == null:
		return
	var sizes := Vector2(_eyes[0].scale.x, _eyes[1].scale.x)
	mat.set_shader_parameter("eye_size", sizes)
	mat.set_shader_parameter("eye_height",
		Vector2(_eyes[0].scale.y, _eyes[1].scale.y) / sizes.max(Vector2.ONE * 0.001))
	mat.set_shader_parameter("pupil_size", Vector2.ONE * _pupil_size)
	# A pupil turned MAX_LOOK_ANGLE sideways sits at the edge of the white (1).
	var reach: float = sin(MAX_LOOK_ANGLE)
	var l := Vector2(_look_dirs[0].x, _look_dirs[0].y) / reach
	var r := Vector2(_look_dirs[1].x, _look_dirs[1].y) / reach
	mat.set_shader_parameter("pupil_offset", Vector4(l.x, l.y, r.x, r.y))
	mat.set_shader_parameter("happy", 1.0 if mood == Mood.HAPPY else 0.0)
	mat.set_shader_parameter("white_glow", _white_glow)
