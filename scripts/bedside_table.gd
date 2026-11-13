extends Prop
## The bedside table, with a drawer that really slides.
##
## The drawer is its own little body (a Prop, so the beam can grab it by its
## front and pull it open). The DrawerRunner joint ties it to the table and
## lets it move only one way: in and out along the table's front-back axis,
## between shut and DRAWER_TRAVEL out. Everything else is ordinary physics:
## stop the table suddenly or tip it forward and the drawer slides out; tip
## it back and it slides home. What's inside rides along and can fall out.
##
## A joint "motor" aiming for zero speed, with a small force limit, stands in
## for the runners' friction, so the drawer stays put unless it's jolted or
## tipped far enough.

## How far the drawer slides out, in metres.
const DRAWER_TRAVEL: float = 0.26
## The runners' friction, in newtons. Higher = it takes a harder jolt or a
## steeper tilt to move the drawer.
const RUNNER_FRICTION: float = 2.5

@onready var drawer: Prop = $Drawer
@onready var _runner: Generic6DOFJoint3D = $DrawerRunner


func _ready() -> void:
	super()
	_detach_part(drawer)

	# The joint's axes are its own (lined up with the table's). Every axis is
	# locked by default; free the slide along Z, between the stops.
	_runner.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
	_runner.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, DRAWER_TRAVEL)
	_runner.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_MOTOR, true)
	_runner.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_MOTOR_TARGET_VELOCITY, 0.0)
	_runner.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_MOTOR_FORCE_LIMIT, RUNNER_FRICTION)


## How far the drawer is out, in metres (0 = shut).
func drawer_out() -> float:
	return to_local(drawer.global_position).z
