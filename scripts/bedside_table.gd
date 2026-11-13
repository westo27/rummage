extends Prop
## The bedside table. Its drawer slides open when the beam throws it, and
## slides shut again the next time the beam picks it up.
##
## The drawer isn't a separate body: its meshes and collision shapes are
## children of the table (every child named "Drawer..."), moved together.

## How far the drawer slides out, in metres, and how long it takes.
const DRAWER_TRAVEL: float = 0.26
const OPEN_SECONDS: float = 0.18
const CLOSE_SECONDS: float = 0.3

## 0 = shut, 1 = fully open. Setting it moves the drawer.
var drawer_open: float = 0.0:
	set(value):
		drawer_open = value
		_place_drawer()

var _drawer_parts: Array[Node3D] = []
var _drawer_closed_z: Array[float] = []
var _tween: Tween = null


func _ready() -> void:
	super()
	for child in get_children():
		if child is Node3D and child.name.begins_with("Drawer"):
			_drawer_parts.append(child)
			_drawer_closed_z.append(child.position.z)


func thrown() -> void:
	_slide_drawer(1.0, OPEN_SECONDS)


func start_hold(holder: PhysicsBody3D) -> void:
	super(holder)
	_slide_drawer(0.0, CLOSE_SECONDS)


func _slide_drawer(target: float, seconds: float) -> void:
	if _tween != null:
		_tween.kill()
	# A tween changes a property smoothly over time. Running it in the physics
	# tick keeps it in step with physics interpolation (see "Smoothness").
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "drawer_open", target, seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _place_drawer() -> void:
	for i in _drawer_parts.size():
		var part: Node3D = _drawer_parts[i]
		part.position.z = _drawer_closed_z[i] + drawer_open * DRAWER_TRAVEL
		# Keep the "too heavy" shudder (prop.gd) wobbling around the new spot.
		if part is MeshInstance3D:
			var mesh_index: int = _meshes.find(part)
			if mesh_index >= 0:
				_mesh_rest_positions[mesh_index] = part.position
