extends Prop
## The rug's invisible handle (see rug.gd). Parked and frozen when not held;
## the beam picks it up in place of the cloth.

## Cloth points within this distance of where you grab are held.
const PIN_RADIUS: float = 0.3

@onready var _rug: Node = get_parent()


func _ready() -> void:
	super()
	_park()


## Called by the beam just before it grabs: move here and take hold.
func prepare_grab(point: Vector3) -> void:
	global_transform = Transform3D(Basis.IDENTITY, point)
	reset_physics_interpolation()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = LAYER_WORLD  # rests on the floor, touches nothing else
	_rug.pin_around(point, PIN_RADIUS)


func why_stuck() -> String:
	return "SOMETHING'S ON IT" if _rug.weighed_down() else ""


func end_hold() -> void:
	super()
	_rug.release_pins()
	_park()


func _park() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
