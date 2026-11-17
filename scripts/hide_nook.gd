class_name HideNook
extends Marker3D
## A place a fleeing creature can dive into and hide properly again, rather
## than cower in the open: under the bed (found by crouching and looking) or
## under the rug (a lump you tread on). One creature per nook.

enum Kind { UNDER_BED, UNDER_RUG }

@export var kind: Kind = Kind.UNDER_BED

var occupant: Creature = null


func _ready() -> void:
	add_to_group("hide_nooks")


func is_free() -> bool:
	return occupant == null or not is_instance_valid(occupant)
