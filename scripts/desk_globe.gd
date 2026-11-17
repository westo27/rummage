extends Prop
## The desk globe: a stand with a brass meridian ring, and the globe itself,
## a Prop of its own turning on the tilted axle (a HingeJoint3D with no
## limits). Grab the globe and the stand holds still while you spin it; let
## go and it keeps turning a good while. Grab the stand to carry the lot.

## How quickly a spin dies away. Low, so a flick keeps it turning.
const SPIN_DAMP: float = 0.25

var ball: Prop


func _ready() -> void:
	keep_still_while_parts_held = true
	super()
	ball = $Ball as Prop
	_detach_part(ball)
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp = SPIN_DAMP


## How fast the globe is turning on its axle, in radians per second.
func spin_speed() -> float:
	return absf(ball.angular_velocity.dot(ball.global_basis.y))
