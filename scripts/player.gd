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
## Capsule height while crouched: as short as a capsule this wide can be.
## The eyes go lower still (crouch_eye_height), down at the floor, as if lying
## flat to peer under the bed.
const CROUCH_HEIGHT: float = 0.7
## How fast the crouch eases in and out (fraction per second).
const CROUCH_EASE: float = 12.0

## 0 standing, 1 fully crouched. Eased, so the camera dips rather than snaps.
var crouch: float = 0.0
var _start_transform: Transform3D
## The standing capsule, for checking there's headroom before standing up.
var _stand_query := PhysicsShapeQueryParameters3D.new()
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


func _ready() -> void:
	_start_transform = global_transform
	# Lets creatures find the player with get_first_node_in_group("player").
	add_to_group("player")
	# The scene's capsule is a shared resource; give this body its own to resize.
	_body_shape.shape = _body_shape.shape.duplicate()
	_stand_query.collision_mask = collision_mask
	_stand_query.exclude = [get_rid()]
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
	speed = lerpf(speed, Game.tune.crouch_speed, crouch)
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


## Hold to crouch. Letting go only stands you up once there's room overhead,
## so you stay ducked under a table until you've crawled out.
func _update_crouch(delta: float) -> void:
	var want: float = 1.0 if Input.is_action_pressed("crouch") or not _room_to_stand() else 0.0
	crouch = move_toward(crouch, want, CROUCH_EASE * delta * 0.5)
	# Ease in/out curve on top of the linear move, so it starts and lands softly.
	var t: float = smoothstep(0.0, 1.0, crouch)
	var height: float = lerpf(STAND_HEIGHT, CROUCH_HEIGHT, t)
	var capsule := _body_shape.shape as CapsuleShape3D
	capsule.height = height
	_body_shape.position.y = height * 0.5  # keep the feet on the floor
	head.position.y = lerpf(Game.tune.stand_eye_height, Game.tune.crouch_eye_height, t)


func _room_to_stand() -> bool:
	if crouch <= 0.0:
		return true
	_stand_query.transform = global_transform.translated_local(Vector3(0.0, STAND_HEIGHT * 0.5 + 0.02, 0.0))
	return get_world_3d().direct_space_state.intersect_shape(_stand_query, 1).is_empty()


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
