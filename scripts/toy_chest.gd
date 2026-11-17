extends LiddedBox
## The toy chest: a hollow painted box whose lid is a light Prop of its own on
## a HingeJoint3D along the back edge, as the wardrobe's doors are. The beam
## lifts the lid; let go short of upright and it drops shut, push it past
## upright and it rests open against its stop.
##
## A LiddedBox, so a creature can hide inside (Creature.hiding_box); it pops
## out once the lid's front edge has lifted far enough.

## How far the lid can swing open: a little past upright.
const LID_SWING: float = deg_to_rad(105.0)
## The hinge's stiffness. Higher = the lid slows down sooner.
const HINGE_DAMP: float = 2.5
## Which way round the hinge opens the lid upward. Found by trying it.
const OPEN_SIGN: float = 1.0
## Front to back across the lid: how far its front edge is from the hinge.
const LID_DEPTH: float = 0.49


func _ready() -> void:
	super()
	_detach_part(lid)  # marks it as our part, so the beam plants us while it's held
	lid.angular_damp = HINGE_DAMP
	var hinge := $LidHinge as HingeJoint3D
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, minf(0.0, OPEN_SIGN * LID_SWING))
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, maxf(0.0, OPEN_SIGN * LID_SWING))


## How far the lid is open, in radians (0 = shut).
func lid_angle() -> float:
	return global_basis.y.angle_to(lid.global_basis.y)


## How high the lid's front edge has lifted (m).
func opening_gap() -> float:
	return sin(minf(lid_angle(), PI / 2.0)) * LID_DEPTH
