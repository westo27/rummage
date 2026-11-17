extends SoftBody3D
## The rug, as cloth: a soft body that drapes, folds and slumps.
##
## The beam can only hold Props (rigid bodies), so the rug has an invisible
## Prop of its own, `grip`. When the beam aims at the cloth it's handed the
## grip instead; just before the grab, the grip jumps to the spot you clicked
## and the cloth points around it are pinned to it (rug_grip.gd). While held,
## those points are moved with the grip every tick and the rest hangs off them.
##
## The rug is on a layer of its own that only meets the floor, so the table
## and balls on it stay put when it moves (and a lifted rug passes through
## furniture rather than knocking it).

## Anything this heavy standing on the rug holds it down (the table, a crate).
const PIN_DOWN_MASS: float = 5.0
## Only things down near the floor count, not a ball flying over it.
const ON_IT_HEIGHT: float = 1.0

@onready var grip: Prop = $Grip

## The pinned points, and where each sits relative to the grip.
var _pinned: PackedInt32Array = []
var _pinned_local: PackedVector3Array = []
var _count: int = 0


func _ready() -> void:
	add_to_group("rug")


## True if the cloth lies over `point`: one of its points is just above it.
## (Creatures hide under it as lumps; see creature.gd.)
func covers(point: Vector3) -> bool:
	for i in _point_count():
		var at: Vector3 = get_point_transform(i)
		if Vector2(at.x - point.x, at.z - point.z).length() < 0.12 and at.y > point.y - 0.1 and at.y < point.y + 0.25:
			return true
	return false


## Wakes the cloth so it notices a lump rising under it or going. A resting
## soft body sleeps, and something moving into it without a push doesn't
## wake it; moving one of its points does.
func wake() -> void:
	if _point_count() > 0:
		PhysicsServer3D.soft_body_move_point(get_physics_rid(), 0, get_point_transform(0))


## Pins every point within `radius` of `point` (or the nearest one) to the grip.
func pin_around(point: Vector3, radius: float) -> void:
	release_pins()
	var nearest: int = 0
	var nearest_distance: float = INF
	for i in _point_count():
		var at: Vector3 = get_point_transform(i)
		var distance: float = at.distance_to(point)
		if distance < radius:
			_pin(i, at)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = i
	if _pinned.is_empty():
		_pin(nearest, get_point_transform(nearest))


func release_pins() -> void:
	for i in _pinned:
		set_point_pinned(i, false)
	_pinned.clear()
	_pinned_local.clear()


## True while something heavy stands over the rug, so it can't be pulled out.
func weighed_down() -> bool:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for i in _point_count():
		var at: Vector3 = get_point_transform(i)
		low = low.min(Vector2(at.x, at.z))
		high = high.max(Vector2(at.x, at.z))
	for prop: Prop in get_tree().get_nodes_in_group("props"):
		if prop == grip or prop.is_held or prop.mass < PIN_DOWN_MASS:
			continue
		var at: Vector3 = prop.global_position
		if at.y < ON_IT_HEIGHT and at.x > low.x and at.x < high.x and at.z > low.y and at.z < high.y:
			return true
	return false


## The middle of the cloth, wherever it has got to.
func centre() -> Vector3:
	var total := Vector3.ZERO
	for i in _point_count():
		total += get_point_transform(i)
	return total / _point_count()


func _physics_process(_delta: float) -> void:
	# Carry the pinned points along with the grip.
	for k in _pinned.size():
		PhysicsServer3D.soft_body_move_point(get_physics_rid(), _pinned[k],
			grip.global_transform * _pinned_local[k])


func _pin(index: int, at: Vector3) -> void:
	set_point_pinned(index, true)
	_pinned.append(index)
	_pinned_local.append(grip.to_local(at))


## One cloth point per mesh vertex. (At runtime the soft body swaps its
## PlaneMesh for a plain mesh, so read the count from the surface.)
func _point_count() -> int:
	if _count == 0:
		_count = (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return _count
