extends Prop
## Furniture with drawers that really slide: the bedside table and the chest
## of drawers.
##
## Each drawer is its own body (a Prop child named "Drawer...", so the beam
## can grab it by its front and pull it open), tied on by a Generic6DOFJoint3D
## named after it plus "Runner". The joint lets the drawer move only one way:
## in and out along the furniture's front-back axis, between shut and
## `drawer_travel` out. Everything else is ordinary physics: stop the
## furniture suddenly or tip it forward and the drawers slide out; tip it back
## and they slide home. What's inside rides along and can fall out.
##
## A joint "motor" aiming for zero speed, with a small force limit, stands in
## for the runners' friction, so a drawer stays put unless it's jolted or
## tipped far enough.

## How far each drawer slides out, in metres.
@export var drawer_travel: float = 0.26
## The runners' friction, in newtons. Higher = it takes a harder jolt or a
## steeper tilt to move a drawer.
@export var runner_friction: float = 2.5

var drawers: Array[Prop] = []
## The first drawer, for furniture that has just one.
var drawer: Prop
var _shut_z: Array[float] = []


func _ready() -> void:
	super()
	for child in get_children():
		if child is Prop and child.name.begins_with("Drawer"):
			drawers.append(child)
	drawer = drawers[0] if not drawers.is_empty() else null
	for each in drawers:
		_shut_z.append(each.position.z)
		_detach_part(each)
		# The joint's axes are its own (lined up with the furniture's). Every
		# axis is locked by default; free the slide along Z, between the stops.
		var runner := get_node(String(each.name) + "Runner") as Generic6DOFJoint3D
		runner.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
		runner.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, drawer_travel)
		runner.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_MOTOR, true)
		runner.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_MOTOR_TARGET_VELOCITY, 0.0)
		runner.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_MOTOR_FORCE_LIMIT, runner_friction)


## How far a drawer is out, in metres (0 = shut).
func drawer_out(index: int = 0) -> float:
	return to_local(drawers[index].global_position).z - _shut_z[index]
