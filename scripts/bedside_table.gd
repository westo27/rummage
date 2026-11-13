extends Prop
## The bedside table. Its drawer slides open when the beam picks it up or
## throws it, and whatever is inside tumbles out. It stays open after that.
##
## The drawer isn't a separate body: its meshes and collision shapes are
## children of the table (every child named "Drawer..."), moved together.
## What's "inside" is any prop whose centre is within the drawer's box when
## it opens. Those ride out with the drawer, then get a push out of the front
## and up, so they spill out reliably rather than depending on how the table
## happens to tilt.

## How far the drawer slides out, in metres, and how long it takes.
const DRAWER_TRAVEL: float = 0.26
const OPEN_SECONDS: float = 0.18
## The drawer's inside, in the table's own space (closed position).
const INSIDE := AABB(Vector3(-0.17, 0.03, -0.16), Vector3(0.34, 0.2, 0.34))
## How hard the contents are flung out (m/s): forward out of the drawer, up,
## and a random sideways scatter.
const SPILL_FORWARD: float = 1.6
const SPILL_UP: float = 1.4
const SPILL_SCATTER: float = 0.6

## 0 = shut, 1 = fully open. Setting it moves the drawer.
var drawer_open: float = 0.0:
	set(value):
		drawer_open = value
		_place_drawer()

var _drawer_parts: Array[Node3D] = []
var _drawer_closed_z: Array[float] = []
var _opened: bool = false
## The props riding in the drawer while it slides open, and where each sits
## in the table's space (drawer closed).
var _carried: Array[Prop] = []
var _carried_local: Array[Vector3] = []


func _ready() -> void:
	super()
	for child in get_children():
		if child is Node3D and child.name.begins_with("Drawer"):
			_drawer_parts.append(child)
			_drawer_closed_z.append(child.position.z)


func thrown() -> void:
	_open_drawer()


func start_hold(holder: PhysicsBody3D) -> void:
	super(holder)
	_open_drawer()


func _open_drawer() -> void:
	if _opened:
		return
	_opened = true
	for prop: Prop in get_tree().get_nodes_in_group("props"):
		var local: Vector3 = to_local(prop.global_position)
		if prop != self and INSIDE.has_point(local):
			_carried.append(prop)
			_carried_local.append(local)
	# A tween changes a property smoothly over time. Running it in the physics
	# tick keeps it in step with physics interpolation (see "Smoothness").
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "drawer_open", 1.0, OPEN_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_spill_contents)


func _spill_contents() -> void:
	var out_of_front: Vector3 = global_basis.z  # the drawer faces the table's +Z
	for prop in _carried:
		var scatter := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * SPILL_SCATTER
		prop.linear_velocity = linear_velocity + out_of_front * SPILL_FORWARD \
			+ Vector3.UP * SPILL_UP + scatter
		prop.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		prop.sleeping = false
	_carried.clear()
	_carried_local.clear()


func _place_drawer() -> void:
	for i in _drawer_parts.size():
		var part: Node3D = _drawer_parts[i]
		part.position.z = _drawer_closed_z[i] + drawer_open * DRAWER_TRAVEL
		# Keep the "too heavy" shudder (prop.gd) wobbling around the new spot.
		if part is MeshInstance3D:
			var mesh_index: int = _meshes.find(part)
			if mesh_index >= 0:
				_mesh_rest_positions[mesh_index] = part.position
	# Carry the contents along, moving with the table too if it's held.
	for i in _carried.size():
		var prop: Prop = _carried[i]
		prop.global_position = to_global(_carried_local[i] + Vector3(0, 0, drawer_open * DRAWER_TRAVEL))
		prop.linear_velocity = linear_velocity
		prop.sleeping = false
