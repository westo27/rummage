extends Prop
## A jack-in-the-box. A hard enough knock springs the catch: the lid flips
## open and the clown bounces up on its spring, wobbles, and stays out.
##
## The lid and the jack are meshes of this one body, posed from code: the
## clown's parts are laid out round the top of the spring, which stretches
## from inside the box as `_rise` goes from 0 (packed away) to 1.

## The knock (m/s) that springs the catch.
@export var pop_speed: float = 2.0

## Where the spring starts, inside the box, and the gap between its coils
## when fully out. The box's top is at y = BOX_TOP.
const BOX_TOP: float = 0.06
const SPRING_BASE: float = -0.045
const COIL_GAP: float = 0.012
const COILS: int = 12
const LID_SWING: float = deg_to_rad(115.0)
## The lid's hinge: along the box's back top edge.
const LID_PIVOT := Vector3(0.0, BOX_TOP, -0.064)
const LID_PARTS: Array[String] = ["Lid", "LidTrim", "LidKnob"]
## Each part of the clown, placed from the top of the spring.
const CLOWN: Dictionary = {
	"Ruff": Vector3(0.0, 0.006, 0.0),
	"Head": Vector3(0.0, 0.04, 0.0),
	"Nose": Vector3(0.0, 0.04, 0.032),
	"EyeL": Vector3(-0.012, 0.05, 0.028),
	"EyeR": Vector3(0.012, 0.05, 0.028),
	"Smile": Vector3(0.0, 0.028, 0.029),
	"CheekL": Vector3(-0.02, 0.034, 0.023),
	"CheekR": Vector3(0.02, 0.034, 0.023),
	"HairL": Vector3(-0.03, 0.045, -0.004),
	"HairR": Vector3(0.03, 0.045, -0.004),
	"Hat": Vector3(0.0, 0.091, 0.0),
	"Pompom": Vector3(0.0, 0.117, 0.0),
}

var popped: bool = false
var _rise: float = 0.0
var _lid_open: float = 0.0
## Seconds since the pop, for the wobble that dies away after it.
var _since_pop: float = 0.0
var _lid_rest: Dictionary = {}


func _ready() -> void:
	super()
	for part: String in LID_PARTS:
		_lid_rest[part] = (get_node(part) as Node3D).transform
	for node: Node3D in _jack_parts():
		node.visible = false
	set_process(false)


## Springs the catch. Also called by tests.
func pop() -> void:
	if popped:
		return
	popped = true
	for node: Node3D in _jack_parts():
		node.visible = true
	($JackShape as CollisionShape3D).set_deferred("disabled", false)
	# A tween animates a property over time; TRANS_ELASTIC overshoots and
	# bounces back, which is the spring.
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_lid_open", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_rise", 1.0, 1.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_since_pop = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_since_pop += delta
	_pose()
	if _since_pop > 2.5:
		set_process(false)


## Called by Prop on every knock it plays.
func _knocked(speed: float) -> void:
	if speed >= pop_speed and not popped:
		pop.call_deferred()


func _pose() -> void:
	var hinge := Transform3D(Basis(Vector3.RIGHT, -LID_SWING * _lid_open), LID_PIVOT) \
		* Transform3D(Basis.IDENTITY, -LID_PIVOT)
	for part: String in LID_PARTS:
		_place(get_node(part) as MeshInstance3D, hinge * (_lid_rest[part] as Transform3D))
	# The whole jack leans from the bottom of the spring as it wobbles.
	var lean: float = sin(_since_pop * 14.0) * 0.3 * exp(-_since_pop * 2.5)
	var sway := Transform3D(Basis(Vector3.BACK, lean), Vector3(0.0, SPRING_BASE, 0.0)) \
		* Transform3D(Basis.IDENTITY, Vector3(0.0, -SPRING_BASE, 0.0))
	var gap: float = COIL_GAP * _rise
	for i in COILS:
		_place(get_node("Spring%d" % (i + 1)) as MeshInstance3D,
			sway * Transform3D(Basis.IDENTITY, Vector3(0.0, SPRING_BASE + gap * i, 0.0)))
	var spring_top := Vector3(0.0, SPRING_BASE + gap * COILS, 0.0)
	for part: String in CLOWN:
		var node := get_node(part) as MeshInstance3D
		_place(node, sway * Transform3D(node.basis, spring_top + (CLOWN[part] as Vector3)))
	# The aura was fitted to the shut box: drop it so the beam refits it.
	if _aura != null:
		_aura.queue_free()
		_aura = null


## Moves a mesh, keeping Prop's record of where it rests (for the shudder).
func _place(mesh: MeshInstance3D, where: Transform3D) -> void:
	mesh.transform = where
	var i: int = _meshes.find(mesh)
	if i >= 0:
		_mesh_rest_positions[i] = where.origin


func _jack_parts() -> Array[Node3D]:
	var parts: Array[Node3D] = []
	for i in COILS:
		parts.append(get_node("Spring%d" % (i + 1)))
	for part: String in CLOWN:
		parts.append(get_node(part))
	return parts
