extends CharacterBody3D
## First-person movement and mouse look.
##
## CharacterBody3D is a body you move yourself (by setting `velocity` and calling
## move_and_slide); physics doesn't push it around the way it pushes a RigidBody3D.
##
## Turning is split over two nodes: left/right (yaw) rotates the whole body,
## up/down (pitch) rotates only the Head node. Doing both on one node would
## tilt the movement direction when you look down.

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var _start_transform: Transform3D


func _ready() -> void:
	_start_transform = global_transform
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
		var sensitivity: float = Game.tune.mouse_sensitivity
		rotate_y(-motion.relative.x * sensitivity)
		head.rotate_x(-motion.relative.y * sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
	var speed: float = Game.tune.run_speed if Input.is_action_pressed("run") else Game.tune.walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()

	if global_position.y < Game.tune.fall_reset_y:
		_reset_to_start()


func _reset_to_start() -> void:
	global_transform = _start_transform
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
