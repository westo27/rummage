extends CharacterBody3D
## First-person movement and mouse look.
##
## CharacterBody3D is a body you move yourself (by setting `velocity` and calling
## move_and_slide); physics doesn't push it around the way it pushes a RigidBody3D.
##
## Turning is split over two nodes: left/right (yaw) rotates the whole body,
## up/down (pitch) rotates only the Head node. Doing both on one node would
## tilt the movement direction when you look down.
##
## Smoothness: physics runs at 60 Hz but the screen may refresh at 144+ Hz.
## Physics interpolation (Project Settings > Physics > Common) makes Godot draw
## moving bodies part-way between their last two physics positions, so they
## glide instead of stepping. The camera is the exception: it's top_level with
## interpolation switched off, and placed by hand every frame (_place_camera):
## position from the interpolated head, rotation straight from the mouse. That
## way looking around responds instantly instead of being smoothed a tick behind.

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

@onready var _body_shape: CollisionShape3D = $CollisionShape3D

const STAND_HEIGHT: float = 1.3
const CROUCH_HEIGHT: float = 0.95
## Capsule height lying flat: as short as a capsule this wide can be. The eyes
## go lower still (prone_eye_height), down at the floor, to peer under the bed.
const PRONE_HEIGHT: float = 0.7

## 0 standing, 0.5 crouched, 1 lying flat. Eased, so the camera dips rather
## than snaps.
var crouch: float = 0.0
var _start_transform: Transform3D
## Standing and crouched capsules, for checking there's headroom to get up.
var _stand_query := PhysicsShapeQueryParameters3D.new()
var _crouch_query := PhysicsShapeQueryParameters3D.new()
## A capsule a little fatter than the player's own, used to find clutter we're
## walking into. Built once and reused every tick.
var _kick_query := PhysicsShapeQueryParameters3D.new()


func _init() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = STAND_HEIGHT
	_kick_query.shape = capsule
	_kick_query.collision_mask = 16  # the "clutter" layer
	var standing := CapsuleShape3D.new()
	standing.radius = 0.34  # a hair thinner, so touching a wall isn't "blocked"
	standing.height = STAND_HEIGHT
	_stand_query.shape = standing
	var crouched := standing.duplicate() as CapsuleShape3D
	crouched.height = CROUCH_HEIGHT
	_crouch_query.shape = crouched


func _ready() -> void:
	_start_transform = global_transform
	# Lets creatures find the player with get_first_node_in_group("player").
	add_to_group("player")
	# The scene's capsule is a shared resource; give this body its own to resize.
	_body_shape.shape = _body_shape.shape.duplicate()
	_stand_query.collision_mask = collision_mask
	_stand_query.exclude = [get_rid()]
	_crouch_query.collision_mask = collision_mask
	_crouch_query.exclude = [get_rid()]
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_place_camera(head.global_position)


# Every rendered frame: put the camera at the head's *drawn* (interpolated)
# position, so it moves as smoothly as everything else.
func _process(_delta: float) -> void:
	_place_camera(head.get_global_transform_interpolated().origin)


func _place_camera(origin: Vector3) -> void:
	# Euler angles (pitch, yaw, roll) applied in Godot's usual Y-then-X order:
	# turn left/right first, then tilt up/down. Same result as body + head.
	var look := Basis.from_euler(Vector3(head.rotation.x, rotation.y, 0.0))
	camera.global_transform = Transform3D(look, origin)


# _input runs for every node before any _unhandled_input does. The recapture
# click is handled here so it's swallowed before the beam (which listens in
# _unhandled_input) ever sees it, and so can't also fire the grab beam.
func _input(event: InputEvent) -> void:
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and captured:
		var motion := event as InputEventMouseMotion
		# From the player's saved settings, not the tunable: the tunable is only
		# the starting value for a new player. Esc is handled by the pause menu.
		var sensitivity: float = Game.settings.mouse_sensitivity()
		var pitch_sign: float = 1.0 if Game.settings.invert_look else -1.0
		rotate_y(-motion.relative.x * sensitivity)
		head.rotate_x(pitch_sign * motion.relative.y * sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))


# _physics_process runs at a fixed 60 Hz in step with the physics engine;
# _process runs once per rendered frame at whatever the frame rate is.
# Anything that moves a body belongs in _physics_process.
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= Game.tune.gravity * delta

	# get_vector returns x = right minus left, y = back minus forward.
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# transform.basis turns "forward relative to me" into a world direction.
	var direction: Vector3 = (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	_update_crouch(delta)
	var speed: float = Game.tune.run_speed if Input.is_action_pressed("run") else Game.tune.walk_speed
	speed = _by_crouch(speed, Game.tune.crouch_speed, Game.tune.prone_speed, false)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
	_kick_clutter()

	if global_position.y < Game.tune.fall_reset_y:
		_reset_to_start()

	# The beam (a child, so its physics tick runs after this one) aims from the
	# camera. Put the camera at the exact physics position for that, rather than
	# the in-between drawn position _process will use for the next frame.
	_place_camera(head.global_position)


## Hold C to crouch, Z to lie flat. Letting go only gets you up as far as
## there's room overhead, so you stay down under a table or the bed until
## you've crawled out.
func _update_crouch(delta: float) -> void:
	var want: float = 0.0
	if Input.is_action_pressed("prone"):
		want = 1.0
	elif Input.is_action_pressed("crouch"):
		want = 0.5
	if want < 0.5 and crouch > 0.0 and not _has_room(_stand_query, STAND_HEIGHT):
		want = 0.5
	if want < 1.0 and crouch > 0.5 and not _has_room(_crouch_query, CROUCH_HEIGHT):
		want = 1.0
	crouch = move_toward(crouch, want, 0.5 * delta / Game.tune.crouch_time)
	var height: float = _by_crouch(STAND_HEIGHT, CROUCH_HEIGHT, PRONE_HEIGHT)
	var capsule := _body_shape.shape as CapsuleShape3D
	capsule.height = height
	_body_shape.position.y = height * 0.5  # keep the feet on the floor
	head.position.y = _by_crouch(Game.tune.stand_eye_height, Game.tune.crouch_eye_height, Game.tune.prone_eye_height)


## Blends standing -> crouched over crouch 0..0.5, then crouched -> flat over
## 0.5..1. Eased by default (smoothstep), so each move starts and lands softly.
func _by_crouch(stand: float, crouched: float, flat: float, eased: bool = true) -> float:
	var t: float = clampf(crouch * 2.0, 0.0, 2.0)
	if t <= 1.0:
		return lerpf(stand, crouched, smoothstep(0.0, 1.0, t) if eased else t)
	t -= 1.0
	return lerpf(crouched, flat, smoothstep(0.0, 1.0, t) if eased else t)


func _has_room(query: PhysicsShapeQueryParameters3D, height: float) -> bool:
	query.transform = global_transform.translated_local(Vector3(0.0, height * 0.5 + 0.02, 0.0))
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Light props ("clutter", see prop.gd) don't block the player's movement, so
## instead we look for any we're walking into and fling them ahead, a bit
## faster than we're moving, so we wade through the mess instead of snagging.
func _kick_clutter() -> void:
	var walk := Vector3(velocity.x, 0.0, velocity.z)
	if walk.length() < 0.5:
		return
	var walk_dir: Vector3 = walk.normalized()
	var kick_speed: float = walk.length() * Game.tune.player_kick_factor

	_kick_query.transform = global_transform.translated_local(Vector3(0.0, STAND_HEIGHT * 0.5, 0.0))
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(_kick_query, 16)
	for hit in hits:
		var prop := hit.collider as Prop
		if prop == null or prop.is_held:
			continue
		var away: Vector3 = prop.global_position - global_position
		away.y = 0.0
		if away.dot(walk_dir) <= 0.0:
			continue  # it's behind us; leave it
		var push_dir: Vector3 = (away.normalized() + walk_dir).normalized()
		# Only ever speed it up along the push, never slow down something
		# already flying away, and only give the little upward hop once.
		var current: float = prop.linear_velocity.dot(push_dir)
		if current < kick_speed:
			prop.linear_velocity += push_dir * (kick_speed - current) + Vector3.UP * 1.0
			prop.sleeping = false


func _reset_to_start() -> void:
	global_transform = _start_transform
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	# A teleport, not movement: tell interpolation not to draw a glide from the
	# old spot to the new one.
	reset_physics_interpolation()
