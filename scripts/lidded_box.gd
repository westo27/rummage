class_name LiddedBox
extends Prop
## A hollow box with a loose lid: the shoe boxes and the shape sorter.
##
## The lid is its own light Prop (a child named "Lid"), resting on the walls
## with a skirt that hangs down outside them so it sits square. Nothing ties
## it on: the beam lifts it off, drops it back, and a tumble can throw it.
## A creature can hide inside (Creature.hiding_box) and pops out once the
## lid leaves a gap it fits through.
##
## The base's floor is a collision shape named "FloorShape", which is where
## a hiding creature sits.

## How far (m) the lid can shift off its seat and still count as on.
@export var lid_off_distance: float = 0.05

var lid: Prop
## Where the lid rests, in the box's own coordinates.
var _lid_seat: Vector3


func _ready() -> void:
	lid = $Lid as Prop
	_lid_seat = lid.position
	super()
	# top_level: the lid stops following the box's transform, so physics
	# moves it as a body of its own.
	var placed: Transform3D = lid.global_transform
	lid.top_level = true
	lid.global_transform = placed
	lid.reset_physics_interpolation()


func lid_on() -> bool:
	return to_local(lid.global_position).distance_to(_lid_seat) < lid_off_distance


## How wide a gap the lid has opened (m): the most it has slid off the rim or
## lifted off its seat. A creature inside waits for a gap it fits through.
func opening_gap() -> float:
	var shift: Vector3 = (to_local(lid.global_position) - _lid_seat).abs()
	return maxf(shift.y, maxf(shift.x, shift.z))


## Top of the floor inside, in the box's own coordinates.
func floor_top() -> float:
	var floor_shape := get_node("FloorShape") as CollisionShape3D
	return floor_shape.position.y + (floor_shape.shape as BoxShape3D).size.y * 0.5


## The lid's meshes share the box's random tint, so they still match.
func _tinted_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = super()
	for child in lid.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
	return meshes
