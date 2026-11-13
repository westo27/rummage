extends Prop
## The wardrobe: a hollow cupboard with two doors on hinges.
##
## Each door is a light Prop of its own, tied on by a HingeJoint3D, so the
## beam can pull it open and it swings by physics. Angular damping on the
## doors stands in for the hinges' stiffness, so they swing and settle rather
## than flapping. (A hinge motor, as the drawer uses for friction, locks a
## Jolt hinge solid, so it isn't used here.)
##
## The wardrobe gates the side-room doorway, so it's frozen in place (a
## static body) until the beam first lifts it. Otherwise yanking a door
## could drag the whole wardrobe off the doorway early.

## How far each door can swing open.
const DOOR_SWING: float = deg_to_rad(110.0)
## The hinges' stiffness. Higher = doors slow down sooner.
const HINGE_DAMP: float = 3.0
## Which way round each hinge opens the door outward. Found by trying it.
const OPEN_SIGN := {"DoorA": -1.0, "DoorB": 1.0}


func _ready() -> void:
	super()
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	for door_name: String in OPEN_SIGN:
		var door := get_node(door_name) as RigidBody3D
		_detach_part(door)
		door.angular_damp = HINGE_DAMP
		var hinge := get_node(door_name + "Hinge") as HingeJoint3D
		var sign: float = OPEN_SIGN[door_name]
		hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, minf(0.0, sign * DOOR_SWING))
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, maxf(0.0, sign * DOOR_SWING))


func start_hold(holder: PhysicsBody3D) -> void:
	freeze = false
	super(holder)


## How far a door is open, in radians (0 = shut).
func door_angle(door_name: String) -> float:
	var door := get_node(door_name) as Node3D
	# The door's own Z runs along its width; shut, it lines up with ours.
	return global_basis.z.angle_to(door.global_basis.z)
